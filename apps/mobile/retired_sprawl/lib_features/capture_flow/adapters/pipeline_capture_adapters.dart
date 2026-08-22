import 'dart:io';

import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_availability.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_choice_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_capability_policy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Local-first persistence via the existing capture pipeline.
class PipelineLocalMomentRepository implements LocalMomentRepository {
  PipelineLocalMomentRepository({
    required CapturePipelineService pipeline,
    required JournalStore journalStore,
  }) : _pipeline = pipeline,
       _journalStore = journalStore;

  final CapturePipelineService _pipeline;
  final JournalStore _journalStore;

  @override
  Stream<PipelineState> get pipelineStates => _pipeline.pipelineStates;

  @override
  Future<CapturePipelineOutcome> saveVoiceCapture({
    required File audioFile,
    required int durationSeconds,
  }) => _pipeline.run(
    audioFile: audioFile,
    durationSeconds: durationSeconds,
  );

  @override
  Future<CapturePipelineOutcome> saveTypedCapture({
    required String transcript,
  }) => _pipeline.saveTextThought(transcript: transcript);

  @override
  Future<CapturePipelineOutcome> retryRemoteForEntry({
    required JournalEntry entry,
  }) async {
    final audioPath = entry.localAudioPath?.trim();
    if (audioPath == null || audioPath.isEmpty) {
      return pipelineFailure(
        CapturePipelineFailure('No audio available for retry.'),
      );
    }
    final audioFile = File(audioPath);
    return _pipeline.run(
      audioFile: audioFile,
      durationSeconds: entry.durationSeconds,
    );
  }

  @override
  Future<CapturePipelineOutcome> attachTypedToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  }) => _pipeline.attachTypedTextToVoiceEntry(
    entry: entry,
    transcript: transcript,
  );

  @override
  Future<JournalEntry?> loadEntry(String entryId) =>
      _journalStore.getById(entryId);

  @override
  Future<int> entryCount() async {
    final entries = await _journalStore.loadAll();
    return entries.length;
  }
}

/// Purpose-specific permission — the on-device-only setting plus consent.
///
/// Delegates to [RemoteProcessingConsentGate] so the capture flow's remote
/// gateways cannot answer differently from the capture pipeline. Fails closed.
class StoreRemoteConsentPolicy implements RemoteConsentPolicy {
  StoreRemoteConsentPolicy(RemoteProcessingConsentStore store)
    : _gate = RemoteProcessingConsentGate(store);

  final RemoteProcessingConsentGate _gate;

  @override
  Future<bool> isGranted(RemoteProcessingPurpose purpose) =>
      _gate.isPurposePermittedNow(purpose);
}

class PipelineRemoteTranscriptionGateway implements RemoteTranscriptionGateway {
  PipelineRemoteTranscriptionGateway(this._consent);

  final RemoteConsentPolicy _consent;

  @override
  Future<bool> transcriptionAllowed() =>
      _consent.isGranted(RemoteProcessingPurpose.remoteTranscription);
}

class PipelineRemoteReflectionGateway implements RemoteReflectionGateway {
  PipelineRemoteReflectionGateway(this._consent);

  final RemoteConsentPolicy _consent;

  @override
  Future<bool> reflectionAllowed() =>
      _consent.isGranted(RemoteProcessingPurpose.remoteReflection);
}

/// Composes device capability, purpose permission, and the stored answer.
class StoreTranscriptionCapabilityPolicy implements TranscriptionCapabilityPort {
  StoreTranscriptionCapabilityPolicy({
    required RemoteProcessingConsentStore consentStore,
    required LocalTranscriptionChoiceStore choiceStore,
    required SpeechLocaleStore speechLocaleStore,
    RemoteConsentPolicy? consentPolicy,
    LocalTranscriptionAvailability? availability,
  }) : _consentStore = consentStore,
       _choiceStore = choiceStore,
       _speechLocaleStore = speechLocaleStore,
       _consent = consentPolicy ?? StoreRemoteConsentPolicy(consentStore),
       // Defaulted from the store rather than left to a caller, because the
       // version of this that defaulted to a locale-less availability check
       // reported iOS "available" on every device and the policy believed it.
       _availability = availability ??
           PlatformLocalTranscriptionAvailability(
             confirmedLocale: speechLocaleStore.read,
           );

  final RemoteProcessingConsentStore _consentStore;
  final LocalTranscriptionChoiceStore _choiceStore;
  final SpeechLocaleStore _speechLocaleStore;
  final RemoteConsentPolicy _consent;
  final LocalTranscriptionAvailability _availability;

  @override
  Future<TranscriptionCapabilityOutcome> evaluate() async {
    return TranscriptionCapabilityPolicy.decide(
      localSupport: await _availability.check(),
      remoteTranscriptionPermitted: await _consent.isGranted(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      recordedChoice: await _choiceStore.read(),
    );
  }

  @override
  Future<void> recordChoice({required bool allowRemote}) async {
    if (!allowRemote) {
      await _choiceStore.record(LocalTranscriptionChoice.noTranscription);
      return;
    }
    await _consentStore.grantPurpose(
      RemoteProcessingPurpose.remoteTranscription,
    );
    await OnDeviceProcessingStore.clearForGrantedRemoteConsent();
    await _choiceStore.record(LocalTranscriptionChoice.remoteTranscription);
  }

  @override
  Future<void> recordSpeechLocale(ConfirmedSpeechLocale locale) =>
      _speechLocaleStore.confirm(locale);
}