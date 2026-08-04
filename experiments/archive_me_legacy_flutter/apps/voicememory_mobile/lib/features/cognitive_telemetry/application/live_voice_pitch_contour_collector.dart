import 'dart:typed_data';

/// Collects coarse F0 samples from live PCM frames during capture.
class LiveVoicePitchContourCollector {
  static const maxRetainedSamples = 512;

  final List<double> _samples = <double>[];

  void reset() => _samples.clear();

  List<double> snapshot() => List<double>.unmodifiable(_samples);

  /// Direct Hz ingestion for diagnostics and load benchmarks.
  void addFrameHz(double pitchHz) {
    if (pitchHz <= 0) return;
    _appendSample(pitchHz);
  }

  List<double> getContour() => snapshot();

  void ingestPcm16Frame(Int16List frame, {int sampleRateHz = 16000}) {
    final pitchHz = _estimatePitchHz(frame, sampleRateHz);
    if (pitchHz == null) return;
    _appendSample(pitchHz);
  }

  void ingestPcm16LeBytes(List<int> pcmBytes, {int sampleRateHz = 16000}) {
    if (pcmBytes.length < 4) return;
    final bytes = pcmBytes is Uint8List
        ? pcmBytes
        : Uint8List.fromList(pcmBytes);
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount < 2) return;
    final frame = bytes.buffer.asInt16List(bytes.offsetInBytes, sampleCount);
    ingestPcm16Frame(frame, sampleRateHz: sampleRateHz);
  }

  void _appendSample(double pitchHz) {
    _samples.add(pitchHz);
    if (_samples.length > maxRetainedSamples) {
      _samples.removeAt(0);
    }
  }

  double? _estimatePitchHz(Int16List frame, int sampleRateHz) {
    if (frame.length < 2 || sampleRateHz <= 0) return null;

    var zeroCrossings = 0;
    for (var i = 1; i < frame.length; i++) {
      final previous = frame[i - 1];
      final current = frame[i];
      if ((previous >= 0 && current < 0) || (previous < 0 && current >= 0)) {
        zeroCrossings++;
      }
    }

    if (zeroCrossings < 2) return null;

    final durationSeconds = frame.length / sampleRateHz;
    final pitchHz = zeroCrossings / (2 * durationSeconds);
    if (pitchHz < 75 || pitchHz > 500) return null;
    return pitchHz;
  }
}
