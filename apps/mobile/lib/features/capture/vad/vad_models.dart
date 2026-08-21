/// Aggressiveness modes aligned with WebRTC VAD (0 = quality, 3 = very aggressive).
enum VadAggressiveness {
  quality,
  lowBitrate,
  aggressive,
  veryAggressive,
}

/// One detected natural speech chunk ready for local processing.
class VoiceThoughtSegment {
  const VoiceThoughtSegment({
    required this.sequence,
    required this.filePath,
    required this.durationMs,
    required this.startedAt,
    this.sampleCount = 0,
  });

  final int sequence;
  final String filePath;
  final int durationMs;
  final DateTime startedAt;
  final int sampleCount;

  Duration get duration => Duration(milliseconds: durationMs);
}

/// Streaming configuration for thought-chunk segmentation.
class VadStreamConfig {
  const VadStreamConfig({
    this.sampleRateHz = 16000,
    this.frameDurationMs = 20,
    this.aggressiveness = VadAggressiveness.quality,
    this.minSpeechMs = 450,
    this.silenceHangoverMs = 900,
    this.maxSegmentMs = 45000,
    this.preSpeechPaddingMs = 200,
  });

  final int sampleRateHz;
  final int frameDurationMs;
  final VadAggressiveness aggressiveness;
  final int minSpeechMs;
  final int silenceHangoverMs;
  final int maxSegmentMs;
  final int preSpeechPaddingMs;

  int get frameSampleCount =>
      (sampleRateHz * frameDurationMs / 1000).round();
}

/// Snapshot emitted when a thought segment closes.
class VadSegmentEvent {
  const VadSegmentEvent({
    required this.segment,
    required this.closedBecause,
  });

  final VoiceThoughtSegment segment;
  final VadSegmentCloseReason closedBecause;
}

enum VadSegmentCloseReason {
  silenceBoundary,
  maxDuration,
  manualStop,
}

enum VadStreamState {
  idle,
  listening,
  speech,
  hangover,
}
