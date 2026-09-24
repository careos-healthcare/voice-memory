import 'package:archiveme_mobile/audio/playback_service.dart'
    show PlaybackService;
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart'
    show PlaybackService;

enum PlaybackPhase { idle, preparing, playing, paused, error }

enum PlaybackSourceKind { none, file, livePcm }

/// Immutable playback session state — updated atomically by [PlaybackService].
class PlaybackState {
  const PlaybackState({
    this.phase = PlaybackPhase.idle,
    this.sourceKind = PlaybackSourceKind.none,
    this.filePath,
    this.queueDepth = 0,
    this.activeQueueDepth = 0,
    this.position = Duration.zero,
    this.error,
    this.speed = 1,
    this.trimSilence = true,
  });

  final PlaybackPhase phase;
  final PlaybackSourceKind sourceKind;
  final String? filePath;
  final int queueDepth;
  final int activeQueueDepth;
  final Duration position;
  final String? error;
  final double speed;
  final bool trimSilence;

  bool get isLiveSpeaking =>
      sourceKind == PlaybackSourceKind.livePcm && activeQueueDepth > 0;

  PlaybackState copyWith({
    PlaybackPhase? phase,
    PlaybackSourceKind? sourceKind,
    String? filePath,
    int? queueDepth,
    int? activeQueueDepth,
    Duration? position,
    String? error,
    double? speed,
    bool? trimSilence,
    bool clearFilePath = false,
    bool clearError = false,
  }) {
    return PlaybackState(
      phase: phase ?? this.phase,
      sourceKind: sourceKind ?? this.sourceKind,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      queueDepth: queueDepth ?? this.queueDepth,
      activeQueueDepth: activeQueueDepth ?? this.activeQueueDepth,
      position: position ?? this.position,
      error: clearError ? null : (error ?? this.error),
      speed: speed ?? this.speed,
      trimSilence: trimSilence ?? this.trimSilence,
    );
  }
}

class PlaybackException implements Exception {
  PlaybackException(this.message);
  final String message;
  @override
  String toString() => message;
}
