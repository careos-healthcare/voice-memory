/// Streams microphone PCM chunks at 16 kHz for Gemini Live input.
abstract class LivePcm16CaptureSource {
  bool get isCapturing;

  /// Starts streaming 16-bit LE mono PCM @ 16 kHz chunks to [onChunk].
  Future<void> start({required void Function(List<int> chunk) onChunk});

  /// Stops microphone capture and releases recorder resources.
  Future<void> stop();

  void dispose();
}

class LivePcm16CaptureException implements Exception {
  LivePcm16CaptureException(this.message);

  final String message;

  @override
  String toString() => message;
}
