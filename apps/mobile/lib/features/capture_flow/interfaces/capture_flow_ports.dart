import 'dart:io';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
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
}

class AudioStopResult {
  const AudioStopResult({
    required this.file,
    required this.durationSeconds,
    this.likelySilentInput = false,
  });

  final File file;
  final int durationSeconds;
  final bool likelySilentInput;
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
