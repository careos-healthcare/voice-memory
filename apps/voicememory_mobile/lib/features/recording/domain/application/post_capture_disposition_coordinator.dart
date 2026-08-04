// Public named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../../models/journal_entry.dart';
import '../../../../models/reflection.dart';
import '../../../../models/sync_status.dart';
import '../../../../services/privacy/audio_vault_service.dart';
import '../../../../services/privacy/sensitive_temporary_audio_store.dart';
import '../../../../storage/journal_store.dart';
import '../../../processing_preferences/processing_preferences.dart';
import '../../../processing_preferences/processing_preferences_store.dart';
import '../../../remote_transcription/remote_transcription_disclosure.dart';
import '../../../voice_capture/transcription/on_device_transcription_engine.dart';
import 'on_device_transcription_availability.dart';
import 'vault_persistence_coordinator.dart';

/// What the user may do with a recording that is already safely stored.
enum PostCaptureDisposition {
  transcribeOnDevice,
  transcribeOnline,
  saveAudioOnly,
  deleteRecording,
}

extension PostCaptureDispositionLabel on PostCaptureDisposition {
  String get label => switch (this) {
    PostCaptureDisposition.transcribeOnDevice => 'On this device',
    PostCaptureDisposition.transcribeOnline => 'Online',
    PostCaptureDisposition.saveAudioOnly => 'Save without transcript',
    PostCaptureDisposition.deleteRecording => 'Delete',
  };
}

abstract final class PostCaptureCopy {
  static const title = 'Turn this recording into text?';
  static const body =
      'The audio is already saved in your encrypted vault on this device. '
      'Nothing leaves the device unless you choose Online.';
  static const onDeviceDetail =
      'The local model reads the audio on this device. No upload.';
  static const onlineDetail =
      'The audio is uploaded to our server and sent to OpenAI to produce a '
      'transcript. You are asked to agree first.';
  static const saveAudioOnlyDetail =
      'Keep the recording exactly as it is. You can play, export or delete it '
      'later, and ask for text later too.';
  static const deleteDetail = 'Permanently remove the audio from this device.';
  static const deleteConfirmationTitle = 'Delete this recording?';
  static const deleteConfirmationBody =
      'The audio is removed from the encrypted vault on this device and cannot '
      'be recovered.';
  static const deleteConfirmationCta = 'Delete permanently';
  static const keepCta = 'Keep the recording';
  static const audioOnlyTranscript = '[draft] Audio saved without a transcript';
  static const savedAudioOnlyNote =
      'Recording saved. You can play, export or delete it any time.';
  static const remoteDeclinedNote =
      'The recording stayed on this device. Nothing was uploaded.';
  static const remoteQueuedNote =
      'Recording saved. Online transcription will finish shortly.';
  static const remoteUnavailableNote =
      'Online transcription could not start. The recording is still saved on '
      'this device.';
  static const onDeviceFailedNote =
      'On-device transcription did not produce a transcript. The recording is '
      'still saved on this device.';
}

/// A recording that is already sealed in the encrypted vault and committed to
/// the journal. Every disposition operates on this, never on raw plaintext.
final class ProtectedCapture {
  const ProtectedCapture({
    required this.entryId,
    required this.vaultReference,
    required this.durationSeconds,
  });

  final String entryId;
  final String vaultReference;
  final int durationSeconds;
}

final class PostCaptureChoiceOptions {
  const PostCaptureChoiceOptions({
    required this.available,
    required this.recommended,
  });

  final List<PostCaptureDisposition> available;
  final PostCaptureDisposition recommended;

  bool get offersOnDeviceTranscription =>
      available.contains(PostCaptureDisposition.transcribeOnDevice);
}

enum PostCaptureOutcomeKind {
  transcribedOnDevice,
  queuedForOnlineTranscription,
  savedAudioOnly,
  deleted,
}

final class PostCaptureOutcome {
  const PostCaptureOutcome({
    required this.kind,
    required this.audioRetained,
    this.entry,
    this.note,
  });

  final PostCaptureOutcomeKind kind;
  final bool audioRetained;
  final JournalEntry? entry;
  final String? note;
}

typedef PostCaptureChoiceRequest =
    Future<PostCaptureDisposition?> Function(PostCaptureChoiceOptions options);
typedef RemoteTranscriptionDisclosureApproval = Future<bool> Function();
typedef DeleteRecordingConfirmation = Future<bool> Function();

/// Persist-then-choose orchestration for a finished recording.
///
/// The audio is sealed into the encrypted vault and committed to the journal
/// before the user is asked anything, so declining online transcription — or
/// backgrounding the app mid-question — can never destroy the capture.
final class PostCaptureDispositionCoordinator {
  PostCaptureDispositionCoordinator({
    required AudioVaultService vault,
    required JournalStore Function() journal,
    required OnDeviceTranscriptionEngine onDeviceEngine,
    required RemoteTranscriptionDisclosureGate disclosure,
    required VaultPersistenceCoordinator remoteQueue,
    required Future<void> Function() startRemoteQueue,
    OnDeviceTranscriptionSupport onDeviceSupport =
        const PlatformOnDeviceTranscriptionSupport(),
    OnlineOnlyTranscriptionPreference onlineOnlyPreference =
        const FixedOnlineOnlyTranscriptionPreference(false),
    ProcessingPreferencesReader preferences =
        const FixedProcessingPreferences(),
    SensitiveTemporaryAudioStore? temporaryAudio,
    this.temporaryAudioOwnerId = 'voice-capture',
    String Function()? entryIdFactory,
    DateTime Function()? clock,
  }) : _vault = vault,
       _journal = journal,
       _onDeviceEngine = onDeviceEngine,
       _disclosure = disclosure,
       _remoteQueue = remoteQueue,
       _startRemoteQueue = startRemoteQueue,
       _onDeviceSupport = onDeviceSupport,
       _onlineOnlyPreference = onlineOnlyPreference,
       _preferences = preferences,
       _temporaryAudio =
           temporaryAudio ?? SensitiveTemporaryAudioStore.production,
       _entryIdFactory = entryIdFactory ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  final AudioVaultService _vault;
  final JournalStore Function() _journal;
  final OnDeviceTranscriptionEngine _onDeviceEngine;
  final RemoteTranscriptionDisclosureGate _disclosure;
  final VaultPersistenceCoordinator _remoteQueue;
  final Future<void> Function() _startRemoteQueue;
  final OnDeviceTranscriptionSupport _onDeviceSupport;
  final OnlineOnlyTranscriptionPreference _onlineOnlyPreference;
  final ProcessingPreferencesReader _preferences;
  final SensitiveTemporaryAudioStore _temporaryAudio;
  final String Function() _entryIdFactory;
  final DateTime Function() _clock;

  final String temporaryAudioOwnerId;

  /// Seals [audio] and commits the journal entry, then asks how to handle it.
  ///
  /// Used by both the record screen and the recovery screen so recovered audio
  /// goes through exactly the same choice.
  Future<PostCaptureOutcome> resolve({
    required File audio,
    required int durationSeconds,
    required PostCaptureChoiceRequest requestChoice,
    required RemoteTranscriptionDisclosureApproval requestRemoteDisclosure,
    required DeleteRecordingConfirmation confirmDelete,
    String? entryId,
    DateTime? createdAt,
  }) async {
    final capture = await protect(
      audio: audio,
      durationSeconds: durationSeconds,
      entryId: entryId,
      createdAt: createdAt,
    );
    final available = await options();
    final choice =
        rememberedDisposition(
          available,
          await _storedTranscriptionPreference,
        ) ??
        await requestChoice(available);
    return apply(
      // A dismissed sheet keeps the recording; it never falls back to delete.
      choice ?? PostCaptureDisposition.saveAudioOnly,
      capture: capture,
      requestRemoteDisclosure: requestRemoteDisclosure,
      confirmDelete: confirmDelete,
    );
  }

  /// Step one of every capture: encrypted vault first, questions later.
  Future<ProtectedCapture> protect({
    required File audio,
    required int durationSeconds,
    String? entryId,
    DateTime? createdAt,
  }) async {
    final id = entryId ?? _entryIdFactory();
    final sealed = await _vault.sealCapture(id, audio);
    try {
      await _journal().save(
        JournalEntry(
          id: id,
          createdAt: (createdAt ?? _clock()).toUtc(),
          transcript: '',
          durationSeconds: durationSeconds,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
          syncStatus: SyncStatus.localOnly,
          localAudioVaultRef: sealed.reference,
        ),
        first25Source: 'protected_capture',
      );
    } on Object {
      // Nothing references the ciphertext yet, and the plaintext is still the
      // only recoverable copy, so the orphan object must not be left behind.
      await _vault.delete(sealed.reference);
      rethrow;
    }
    await _releasePlaintext(audio);
    return ProtectedCapture(
      entryId: id,
      vaultReference: sealed.reference,
      durationSeconds: durationSeconds,
    );
  }

  Future<PostCaptureChoiceOptions> options() async {
    final onDeviceAvailable = await isOnDeviceTranscriptionAvailable();
    final onlineOnly = await _onlineOnlyPreference.prefersOnlineOnly();
    return PostCaptureChoiceOptions(
      available: [
        if (onDeviceAvailable) PostCaptureDisposition.transcribeOnDevice,
        PostCaptureDisposition.transcribeOnline,
        PostCaptureDisposition.saveAudioOnly,
        PostCaptureDisposition.deleteRecording,
      ],
      recommended: onDeviceAvailable && !onlineOnly
          ? PostCaptureDisposition.transcribeOnDevice
          : PostCaptureDisposition.transcribeOnline,
    );
  }

  /// The standing answer for this archive, or null when the user must be
  /// asked.
  ///
  /// A remembered `Online` answer still goes through the disclosure gate in
  /// [transcribeOnline]; remembering the choice never remembers consent.
  static PostCaptureDisposition? rememberedDisposition(
    PostCaptureChoiceOptions options,
    TranscriptionPreference preference,
  ) {
    final mapped = switch (preference) {
      TranscriptionPreference.askEachTime => null,
      TranscriptionPreference.onThisDevice =>
        PostCaptureDisposition.transcribeOnDevice,
      TranscriptionPreference.online => PostCaptureDisposition.transcribeOnline,
      TranscriptionPreference.saveWithoutTranscript =>
        PostCaptureDisposition.saveAudioOnly,
    };
    // An answer this device can no longer honour falls back to asking rather
    // than silently picking something else.
    if (mapped == null || !options.available.contains(mapped)) return null;
    return mapped;
  }

  Future<TranscriptionPreference> get _storedTranscriptionPreference async {
    try {
      return (await _preferences.read()).transcription;
    } on Object {
      return TranscriptionPreference.askEachTime;
    }
  }

  /// True only when the platform supports local inference and the existing
  /// on-device model is present. Anything else hides the option entirely.
  Future<bool> isOnDeviceTranscriptionAvailable() async {
    try {
      if (!await _onDeviceSupport.isSupported()) return false;
      return await _onDeviceEngine.isReady();
    } on Object {
      return false;
    }
  }

  Future<PostCaptureOutcome> apply(
    PostCaptureDisposition disposition, {
    required ProtectedCapture capture,
    required RemoteTranscriptionDisclosureApproval requestRemoteDisclosure,
    required DeleteRecordingConfirmation confirmDelete,
  }) {
    return switch (disposition) {
      PostCaptureDisposition.transcribeOnDevice => transcribeOnDevice(capture),
      PostCaptureDisposition.transcribeOnline => transcribeOnline(
        capture,
        requestDisclosure: requestRemoteDisclosure,
      ),
      PostCaptureDisposition.saveAudioOnly => saveAudioOnly(capture),
      PostCaptureDisposition.deleteRecording => deleteRecording(
        capture,
        confirm: confirmDelete,
      ),
    };
  }

  /// Runs the existing on-device engine over a short-lived decrypted lease.
  Future<PostCaptureOutcome> transcribeOnDevice(
    ProtectedCapture capture,
  ) async {
    try {
      final transcript = await _vault.withDecryptedFile(
        capture.vaultReference,
        _onDeviceEngine.transcribe,
      );
      final trimmed = transcript.trim();
      if (trimmed.isEmpty) {
        throw const OnDeviceTranscriptionUnavailable('empty_transcript');
      }
      return PostCaptureOutcome(
        kind: PostCaptureOutcomeKind.transcribedOnDevice,
        audioRetained: true,
        entry: await _writeTranscript(capture, trimmed),
      );
    } on Object {
      return saveAudioOnly(capture, note: PostCaptureCopy.onDeviceFailedNote);
    }
  }

  /// Queues the recording for online transcription, but only once a current
  /// disclosure acceptance exists.
  Future<PostCaptureOutcome> transcribeOnline(
    ProtectedCapture capture, {
    required RemoteTranscriptionDisclosureApproval requestDisclosure,
  }) async {
    if (!await _hasCurrentDisclosureAcceptance()) {
      final accepted = await requestDisclosure();
      // The stored gate stays authoritative, so an approval that failed to
      // persist can never authorize an upload.
      if (!accepted || !await _hasCurrentDisclosureAcceptance()) {
        return saveAudioOnly(capture, note: PostCaptureCopy.remoteDeclinedNote);
      }
    }
    try {
      await _vault.withDecryptedFile(
        capture.vaultReference,
        (plaintext) => _remoteQueue.persistForTranscription(
          protectedAudio: plaintext,
          durationSeconds: capture.durationSeconds,
          entryId: capture.entryId,
        ),
      );
      await _startRemoteQueue();
      return PostCaptureOutcome(
        kind: PostCaptureOutcomeKind.queuedForOnlineTranscription,
        audioRetained: true,
        entry: await _journal().getById(capture.entryId),
        note: PostCaptureCopy.remoteQueuedNote,
      );
    } on Object {
      return saveAudioOnly(
        capture,
        note: PostCaptureCopy.remoteUnavailableNote,
      );
    }
  }

  Future<PostCaptureOutcome> saveAudioOnly(
    ProtectedCapture capture, {
    String? note,
  }) async {
    final existing = await _journal().getById(capture.entryId);
    final entry = existing != null && existing.transcript.trim().isNotEmpty
        ? existing
        : await _writeTranscript(capture, PostCaptureCopy.audioOnlyTranscript);
    return PostCaptureOutcome(
      kind: PostCaptureOutcomeKind.savedAudioOnly,
      audioRetained: true,
      entry: entry,
      note: note ?? PostCaptureCopy.savedAudioOnlyNote,
    );
  }

  Future<PostCaptureOutcome> deleteRecording(
    ProtectedCapture capture, {
    required DeleteRecordingConfirmation confirm,
  }) async {
    if (!await confirm()) return saveAudioOnly(capture);
    await _journal().delete(capture.entryId);
    await _vault.delete(capture.vaultReference);
    return const PostCaptureOutcome(
      kind: PostCaptureOutcomeKind.deleted,
      audioRetained: false,
    );
  }

  Future<bool> _hasCurrentDisclosureAcceptance() async {
    try {
      return (await _disclosure.check(
        purpose: RemoteProcessingPurpose.transcription,
      )).isAccepted;
    } on Object {
      return false;
    }
  }

  Future<JournalEntry> _writeTranscript(
    ProtectedCapture capture,
    String transcript,
  ) async {
    final store = _journal();
    final existing = await store.getById(capture.entryId);
    if (existing == null) {
      throw StateError('Protected capture ${capture.entryId} is missing.');
    }
    final updated = existing.copyWith(transcript: transcript);
    await store.save(updated, first25Source: 'protected_capture_transcript');
    return updated;
  }

  Future<void> _releasePlaintext(File audio) async {
    try {
      await _temporaryAudio.markEncryptionComplete(
        file: audio,
        ownerId: temporaryAudioOwnerId,
      );
    } on Object {
      await _vault.secureDeletePlaintext(audio);
    }
  }
}
