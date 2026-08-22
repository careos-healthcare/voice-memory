import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_error_state.dart';

/// User-visible session fault surfaced during an active live voice capture.
class LiveVoiceSessionFault {
  const LiveVoiceSessionFault({
    required this.reason,
    required this.userMessage,
    required this.errorState,
    this.recoverable = false,
  });

  final String reason;
  final String userMessage;
  final LiveVoiceErrorState errorState;
  final bool recoverable;
}

/// Redacted counters suitable for debug logs and manual E2E verification.
class LiveVoiceDiagnosticsSnapshot {
  const LiveVoiceDiagnosticsSnapshot({
    required this.pcmChunksSent,
    required this.audioChunksReceived,
    required this.audioBytesReceived,
    required this.reconnectAttempts,
    required this.sessionFaults,
    required this.firstAudioLatencyMs,
    required this.playbackQueueDepth,
  });

  final int pcmChunksSent;
  final int audioChunksReceived;
  final int audioBytesReceived;
  final int reconnectAttempts;
  final int sessionFaults;
  final int? firstAudioLatencyMs;
  final int playbackQueueDepth;

  @override
  String toString() {
    return 'LiveVoiceDiagnosticsSnapshot('
        'pcmChunksSent=$pcmChunksSent, '
        'audioChunksReceived=$audioChunksReceived, '
        'audioBytesReceived=$audioBytesReceived, '
        'reconnectAttempts=$reconnectAttempts, '
        'sessionFaults=$sessionFaults, '
        'firstAudioLatencyMs=$firstAudioLatencyMs, '
        'playbackQueueDepth=$playbackQueueDepth'
        ')';
  }
}