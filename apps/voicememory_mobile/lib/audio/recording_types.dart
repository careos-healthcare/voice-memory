import 'dart:io';

import '../features/voice_capture/audio/audio_level_monitor.dart';

enum RecordingPhase {
  idle,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  recording,
  error,
}

/// Immutable capture session state — updated atomically by [RecordingService].
class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.currentDuration = Duration.zero,
    this.activePath,
    this.error,
  });

  final RecordingPhase phase;
  final Duration currentDuration;
  final String? activePath;
  final String? error;

  RecordingState copyWith({
    RecordingPhase? phase,
    Duration? currentDuration,
    String? activePath,
    String? error,
    bool clearActivePath = false,
    bool clearError = false,
  }) {
    return RecordingState(
      phase: phase ?? this.phase,
      currentDuration: currentDuration ?? this.currentDuration,
      activePath: clearActivePath ? null : (activePath ?? this.activePath),
      error: clearError ? null : (error ?? this.error),
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
  });

  final File file;
  final int durationSeconds;
  final bool likelySilentInput;
  final AudioLevelSummary? audioLevelSummary;
  final String? captureInputPortName;
  final String? captureInputPortType;
}

class RecordingException implements Exception {
  RecordingException(this.message);
  final String message;
  @override
  String toString() => message;
}
