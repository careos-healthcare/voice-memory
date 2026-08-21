import 'dart:io';

import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_level_monitor.dart';

enum RecordingPhase {
  idle,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  recording,
  error,
}

/// Payload emitted when a capture session finishes and is ready for local queueing.
class RecordingCompletion {
  const RecordingCompletion({
    required this.file,
    required this.durationMs,
  });

  final File file;
  final int durationMs;
}

/// Immutable capture session state — updated atomically by [RecordingService].
class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.currentDuration = Duration.zero,
    this.activePath,
    this.error,
    this.recordingCompletion,
  });

  final RecordingPhase phase;
  final Duration currentDuration;
  final String? activePath;
  final String? error;
  final RecordingCompletion? recordingCompletion;

  RecordingState copyWith({
    RecordingPhase? phase,
    Duration? currentDuration,
    String? activePath,
    String? error,
    RecordingCompletion? recordingCompletion,
    bool clearActivePath = false,
    bool clearError = false,
    bool clearRecordingCompletion = false,
  }) {
    return RecordingState(
      phase: phase ?? this.phase,
      currentDuration: currentDuration ?? this.currentDuration,
      activePath: clearActivePath ? null : (activePath ?? this.activePath),
      error: clearError ? null : (error ?? this.error),
      recordingCompletion: clearRecordingCompletion
          ? null
          : (recordingCompletion ?? this.recordingCompletion),
    );
  }
}

class RecordingResult {
  const RecordingResult({
    required this.file,
    required this.durationSeconds,
    this.likelySilentInput = false,
    this.audioLevelSummary,
    this.captureInputPortName,
    this.captureInputPortType,
    this.thoughtSegments = const [],
  });

  final File file;
  final int durationSeconds;
  final bool likelySilentInput;
  final AudioLevelSummary? audioLevelSummary;
  final String? captureInputPortName;
  final String? captureInputPortType;
  final List<VoiceThoughtSegment> thoughtSegments;
}

class RecordingException implements Exception {
  RecordingException(this.message);
  final String message;
  @override
  String toString() => message;
}