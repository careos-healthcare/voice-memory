import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';

/// Writes mono PCM16 LE segments as lightweight WAV files for local processing.
class VadSegmentWriter {
  VadSegmentWriter({
    required this.outputDirectory,
    this.sampleRateHz = 16000,
  });

  final String outputDirectory;
  final int sampleRateHz;

  int _sequence = 0;
  IOSink? _sink;
  String? _activePath;
  DateTime? _startedAt;
  var _sampleCount = 0;

  String? get activePath => _activePath;

  Future<void> beginSegment() async {
    await _closeSink();
    _sequence += 1;
    _startedAt = DateTime.now().toUtc();
    _sampleCount = 0;
    await Directory(outputDirectory).create(recursive: true);
    _activePath =
        '$outputDirectory/vad_segment_${_sequence}_${_startedAt!.millisecondsSinceEpoch}.wav';
    final file = File(_activePath!);
    _sink = file.openWrite(mode: FileMode.writeOnly);
    _sink!.add(_wavHeaderPlaceholder());
  }

  void appendPcm(Uint8List pcmLeBytes) {
    final sink = _sink;
    if (sink == null || pcmLeBytes.isEmpty) return;
    sink.add(pcmLeBytes);
    _sampleCount += pcmLeBytes.length ~/ 2;
  }

  Future<VoiceThoughtSegment?> finalizeSegment({
    VadSegmentCloseReason reason = VadSegmentCloseReason.silenceBoundary,
  }) async {
    final path = _activePath;
    final startedAt = _startedAt;
    final samples = _sampleCount;
    if (path == null || startedAt == null || samples == 0) {
      await _closeSink();
      return null;
    }

    await _closeSink();
    await _patchWavHeader(path, samples);

    return VoiceThoughtSegment(
      sequence: _sequence,
      filePath: path,
      durationMs: (samples * 1000 / sampleRateHz).round(),
      startedAt: startedAt,
      sampleCount: samples,
    );
  }

  Future<void> dispose() async {
    await _closeSink();
  }

  Future<void> _closeSink() async {
    final sink = _sink;
    _sink = null;
    if (sink == null) return;
    try {
      await sink.flush();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
    try {
      await sink.close();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
  }

  Uint8List _wavHeaderPlaceholder() {
    return Uint8List(44);
  }

  Future<void> _patchWavHeader(String path, int sampleCount) async {
    final file = File(path);
    final dataSize = sampleCount * 2;
    final header = _buildWavHeader(
      sampleRateHz: sampleRateHz,
      dataSize: dataSize,
    );
    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.setPosition(0);
      await raf.writeFrom(header);
    } finally {
      await raf.close();
    }
  }

  static Uint8List _buildWavHeader({
    required int sampleRateHz,
    required int dataSize,
  }) {
    final byteRate = sampleRateHz * 2;
    final blockAlign = 2;
    final chunkSize = 36 + dataSize;
    final buffer = BytesBuilder();
    buffer.add('RIFF'.codeUnits);
    buffer.add(_le32(chunkSize));
    buffer.add('WAVE'.codeUnits);
    buffer.add('fmt '.codeUnits);
    buffer.add(_le32(16));
    buffer.add(_le16(1));
    buffer.add(_le16(1));
    buffer.add(_le32(sampleRateHz));
    buffer.add(_le32(byteRate));
    buffer.add(_le16(blockAlign));
    buffer.add(_le16(16));
    buffer.add('data'.codeUnits);
    buffer.add(_le32(dataSize));
    return buffer.toBytes();
  }

  static Uint8List _le16(int value) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

  static Uint8List _le32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
}