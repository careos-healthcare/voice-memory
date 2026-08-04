import '../models/live_server_event.dart';

/// Accumulates live transcription events into one journal-ready string.
class LiveAudioTranscriptCollector {
  final StringBuffer _input = StringBuffer();
  final StringBuffer _output = StringBuffer();

  void reset() {
    _input.clear();
    _output.clear();
  }

  void ingest(LiveServerEvent event) {
    switch (event) {
      case LiveInputTranscriptionEvent(:final text):
        _appendFragment(_input, text);
      case LiveOutputTranscriptionEvent(:final text):
        _appendFragment(_output, text);
      default:
        break;
    }
  }

  /// Prefers the user's speech transcript; falls back to model output text.
  String get bestTranscript {
    final input = _input.toString().trim();
    if (input.isNotEmpty) return input;
    return _output.toString().trim();
  }

  String get inputTranscript => _input.toString().trim();

  String get outputTranscript => _output.toString().trim();

  void _appendFragment(StringBuffer buffer, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (buffer.isEmpty) {
      buffer.write(trimmed);
      return;
    }
    buffer.write(' ');
    buffer.write(trimmed);
  }
}
