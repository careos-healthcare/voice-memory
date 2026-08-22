import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/reflections/data/whisper_model_contract.dart';

/// Converts mono PCM16 WAV into Whisper mel input features.
abstract final class WhisperAudioProcessor {
  WhisperAudioProcessor._();

  static Float32List? buildMelFeaturesFromFile(File audioFile) {
    final bytes = _readWavPcm(audioFile);
    if (bytes == null || bytes.isEmpty) return null;
    return buildMelFeaturesFromPcm(bytes, sampleRateHz: WhisperModelContract.sampleRateHz);
  }

  static Float32List buildMelFeaturesFromPcm(
    Int16List pcm, {
    required int sampleRateHz,
  }) {
    final maxSamples =
        WhisperModelContract.sampleRateHz * WhisperModelContract.maxAudioSeconds;
    final clipped = pcm.length > maxSamples
        ? Int16List.sublistView(pcm, 0, maxSamples)
        : pcm;

    final floats = Float32List(clipped.length);
    for (var i = 0; i < clipped.length; i++) {
      floats[i] = clipped[i] / 32768.0;
    }

    final frames = _computeLogMel(floats, sampleRateHz: sampleRateHz);
    final flat = Float32List(
      WhisperModelContract.nMelBins * WhisperModelContract.maxFrames,
    );

    for (var frame = 0; frame < WhisperModelContract.maxFrames; frame++) {
      for (var bin = 0; bin < WhisperModelContract.nMelBins; bin++) {
        final srcFrame = frame < frames.length ? frame : frames.length - 1;
        flat[frame * WhisperModelContract.nMelBins + bin] =
            frames[srcFrame][bin];
      }
    }
    return flat;
  }

  static Int16List? _readWavPcm(File file) {
    if (!file.existsSync()) return null;
    final data = file.readAsBytesSync();
    if (data.length < 44) return null;
    if (String.fromCharCodes(data.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(data.sublist(8, 12)) != 'WAVE') return null;

    var offset = 12;
    var sampleRate = WhisperModelContract.sampleRateHz;
    var bitsPerSample = 16;
    var dataOffset = -1;
    var dataSize = 0;

    while (offset + 8 <= data.length) {
      final chunkId = String.fromCharCodes(data.sublist(offset, offset + 4));
      final chunkSize = _le32(data, offset + 4);
      final chunkStart = offset + 8;
      if (chunkId == 'fmt ') {
        sampleRate = _le32(data, chunkStart + 4);
        bitsPerSample = _le16(data, chunkStart + 14);
      } else if (chunkId == 'data') {
        dataOffset = chunkStart;
        dataSize = chunkSize;
        break;
      }
      offset = chunkStart + chunkSize;
    }

    if (dataOffset < 0 || bitsPerSample != 16) return null;
    final end = math.min(dataOffset + dataSize, data.length);
    final pcmBytes = data.sublist(dataOffset, end);
    final sampleCount = pcmBytes.length ~/ 2;
    final pcm = Int16List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      final lo = pcmBytes[i * 2];
      final hi = pcmBytes[i * 2 + 1];
      var sample = (hi << 8) | lo;
      if (sample > 32767) sample -= 65536;
      pcm[i] = sample;
    }

    if (sampleRate != WhisperModelContract.sampleRateHz) {
      return _resampleLinear(
        pcm,
        fromRate: sampleRate,
        toRate: WhisperModelContract.sampleRateHz,
      );
    }
    return pcm;
  }

  static Int16List _resampleLinear(
    Int16List input, {
    required int fromRate,
    required int toRate,
  }) {
    if (fromRate == toRate) return input;
    final ratio = fromRate / toRate;
    final outLen = (input.length / ratio).floor();
    final out = Int16List(outLen);
    for (var i = 0; i < outLen; i++) {
      final src = i * ratio;
      final idx = src.floor();
      final frac = src - idx;
      final a = input[idx.clamp(0, input.length - 1)];
      final b = input[(idx + 1).clamp(0, input.length - 1)];
      out[i] = (a + (b - a) * frac).round();
    }
    return out;
  }

  static List<Float32List> _computeLogMel(Float32List samples, {required int sampleRateHz}) {
    final hop = WhisperModelContract.hopLength;
    final fft = WhisperModelContract.fftSize;
    final frames = <Float32List>[];
    if (samples.isEmpty) {
      frames.add(Float32List(WhisperModelContract.nMelBins));
      return frames;
    }

    for (var start = 0; start + fft <= samples.length; start += hop) {
      final window = Float32List(fft);
      for (var i = 0; i < fft; i++) {
        final sample = samples[start + i];
        final hann = 0.5 * (1 - math.cos(2 * math.pi * i / (fft - 1)));
        window[i] = sample * hann;
      }
      final power = _powerSpectrum(window);
      frames.add(_melProjection(power, sampleRateHz: sampleRateHz));
      if (frames.length >= WhisperModelContract.maxFrames) break;
    }

    if (frames.isEmpty) {
      frames.add(Float32List(WhisperModelContract.nMelBins));
    }
    return frames;
  }

  static Float32List _powerSpectrum(Float32List window) {
    final n = window.length;
    final power = Float32List(n ~/ 2);
    for (var k = 0; k < power.length; k++) {
      var real = 0.0;
      var imag = 0.0;
      for (var t = 0; t < n; t++) {
        final angle = -2 * math.pi * k * t / n;
        real += window[t] * math.cos(angle);
        imag += window[t] * math.sin(angle);
      }
      power[k] = real * real + imag * imag;
    }
    return power;
  }

  static Float32List _melProjection(Float32List power, {required int sampleRateHz}) {
    final mel = Float32List(WhisperModelContract.nMelBins);
    for (var m = 0; m < mel.length; m++) {
      final lowHz = _melToHz(m / (mel.length + 1) * 40);
      final highHz = _melToHz((m + 1) / (mel.length + 1) * 40);
      final lowBin = (lowHz / (sampleRateHz / power.length)).floor();
      final highBin = (highHz / (sampleRateHz / power.length)).ceil();
      var sum = 0.0;
      for (var b = lowBin; b < highBin && b < power.length; b++) {
        sum += power[b];
      }
      mel[m] = math.log(math.max(sum, 1e-10));
    }
    return mel;
  }

  static double _melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);

  static int _le16(Uint8List data, int offset) =>
      data[offset] | (data[offset + 1] << 8);

  static int _le32(Uint8List data, int offset) =>
      data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}
