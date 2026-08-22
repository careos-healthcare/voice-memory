import 'dart:io';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_capability_policy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';

/// Microphone capture boundary for the strangler flow.
abstract interface class AudioRecorderAdapter {
  Future<MicPermissionResolution> evaluatePermission();
  Future<MicPermissionResolution> requestPermission();
  Future<void> startRecording({required bool permissionVerified});
  Future<AudioStopResult> stopRecording();
  Future<void> cancelRecording();
  Stream<int> get durationSeconds;
  bool get supportsPause;
  Future<void> pauseRecording();
  Future<void> resumeRecording();

  /// Thought chunks emitted while recording (VAD sidecar). Null when unsupported.
  Stream<VadSegmentEvent>? get thoughtSegmentEvents;
}

class AudioStopResult {
  const AudioStopResult({
    required this.file,
    required this.durationSeconds,
    this.likelySilentInput = false,
    this.thoughtSegments = const [],
  });

  final File file;
  final int durationSeconds;
  final bool likelySilentInput;
  final List<VoiceThoughtSegment> thoughtSegments;
}

/// Local-first persistence for captured moments.
abstract interface class LocalMomentRepository {
  Stream<PipelineState> get pipelineStates;

  Future<CapturePipelineOutcome> saveVoiceCapture({
    required File audioFile,
    required int durationSeconds,
  });

  Future<CapturePipelineOutcome> saveTypedCapture({
    required String transcript,
  });

  Future<CapturePipelineOutcome> retryRemoteForEntry({
    required JournalEntry entry,
  });

  Future<CapturePipelineOutcome> attachTypedToVoiceEntry({
    required JournalEntry entry,
    required String transcript,
  });

  Future<JournalEntry?> loadEntry(String entryId);

  Future<int> entryCount();
}

/// Local transcript correction — never rewrites via remote models.
abstract interface class TranscriptCorrectionPort {
  Future<JournalEntry> apply({
    required JournalEntry entry,
    required String correctedText,
  });
}

/// Purpose-specific remote processing consent — fails closed.
abstract interface class RemoteConsentPolicy {
  Future<bool> isGranted(RemoteProcessingPurpose purpose);
}

/// Remote transcription boundary (voice only).
abstract interface class RemoteTranscriptionGateway {
  Future<bool> transcriptionAllowed();
}

/// Remote reflection/analysis boundary.
abstract interface class RemoteReflectionGateway {
  Future<bool> reflectionAllowed();
}

/// Whether anything can transcribe this recording, and what to do if not.
///
/// A device-capability question plus a permission plus the customer's standing
/// answer. No request result is an input, so a dropped connection cannot make
/// [evaluate] ask for a privacy decision.
abstract interface class TranscriptionCapabilityPort {
  Future<TranscriptionCapabilityOutcome> evaluate();

  /// Persists the answer to the one-time prompt.
  ///
  /// [allowRemote] true also grants the transcription purpose and clears the
  /// on-device-only switch, because otherwise "yes, transcribe it" would change
  /// nothing and the customer would be asked again forever.
  Future<void> recordChoice({required bool allowRemote});

  /// Persists the language the customer says they speak into the app.
  ///
  /// Takes a [ConfirmedSpeechLocale] rather than a string so that nothing on
  /// this path can hand over a value it read off the device instead of off a
  /// person.
  Future<void> recordSpeechLocale(ConfirmedSpeechLocale locale);
}

/// Tracks interrupted captures so recovery can resume safely.
abstract interface class PendingCaptureRecoveryStore {
  Future<void> recordPendingVoice({
    required String audioPath,
    required int durationSeconds,
  });

  Future<PendingVoiceCapture?> readPendingVoice();

  Future<void> clearPendingVoice();
}

class PendingVoiceCapture {
  const PendingVoiceCapture({
    required this.audioPath,
    required this.durationSeconds,
  });

  final String audioPath;
  final int durationSeconds;
}

/// Redacted capture telemetry — no transcript or quote content.
abstract interface class CaptureTelemetry {
  void permissionChecked({required String status});
  void permissionRequested({required String status});
  void recorderStarted({required bool success});
  void recorderStopped({required bool success});
  void localSaveStarted({required String kind});
  void localSaveCompleted({required bool success, required String kind});
  void remoteProcessingStarted({required String kind});
  void remoteProcessingCompleted({required bool success, required String kind});
  void illegalTransition({
    required CaptureFlowPhase from,
    required CaptureFlowPhase to,
  });
  void recoverableFailure({required String reason, required bool hasLocalSave});
}

/// Loads privacy-first routine prompts from the local RAG engine.
abstract interface class RoutinePromptGateway {
  Future<RoutineJournalPrompt?> loadPrompt({
    required JournalRoutineKind routine,
    JournalEntry? latestEntry,
    List<JournalEntry>? archiveEntries,
  });
}

/// Reads the user's latest routine anchor preference.
abstract interface class RoutineAnchorLoader {
  Future<RoutineAnchor?> loadLatest();
}
