import 'package:archiveme_mobile/screens/record_entry_screen.dart' show RecordEntryScreen;

/// Vertical slice configuration for [RecordEntryScreen].
abstract final class RecordEntryConfig {
  RecordEntryConfig._();

  /// Unified backend WebSocket for live PCM streaming.
  static const String liveAudioWebSocketUrl = String.fromEnvironment(
    'RECORD_ENTRY_WS_URL',
    defaultValue: 'ws://localhost:8080/api/live-audio/ws',
  );
}