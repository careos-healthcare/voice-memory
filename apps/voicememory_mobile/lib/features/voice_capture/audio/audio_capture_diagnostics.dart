import 'dart:io';

import 'package:record/record.dart';

import 'audio_diag_log.dart';

/// Inspects local capture files and logs device-friendly diagnostics.
abstract class AudioCaptureDiagnostics {
  AudioCaptureDiagnostics._();

  static const RecordConfig iosCaptureConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 44100,
    numChannels: 1,
    bitRate: 128000,
    iosConfig: IosRecordConfig(manageAudioSession: false),
  );

  static void logRecorderConfig({
    RecordConfig config = iosCaptureConfig,
    String containerExtension = 'm4a',
  }) {
    AudioDiagLog.recorderConfig(
      encoder: config.encoder.name,
      sampleRate: config.sampleRate,
      numChannels: config.numChannels,
      bitRate: config.bitRate,
      containerExtension: containerExtension,
    );
  }

  static void logCapturedFile(File file, {int? durationMs}) {
    final path = file.path;
    final exists = file.existsSync();
    final bytes = exists ? file.lengthSync() : 0;
    final extension = _extensionFromPath(path);
    final mimeGuess = guessMimeFromPath(path);
    final firstBytesHex = exists ? _firstBytesHex(file) : '';

    AudioDiagLog.capturedFile(
      path: path,
      exists: exists,
      bytes: bytes,
      extension: extension,
      durationMs: durationMs,
      mimeGuess: mimeGuess,
      firstBytesHex: firstBytesHex,
    );
  }

  static String guessMimeFromPath(String path) {
    return guessMimeFromExtension(_extensionFromPath(path));
  }

  static String guessMimeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'm4a':
      case 'mp4':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'caf':
        return 'audio/x-caf';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  static String uploadContentTypeForPath(String path) {
    final mime = guessMimeFromPath(path);
    return mime == 'application/octet-stream' ? 'audio/mp4' : mime;
  }

  static String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return '';
    return path.substring(dot + 1);
  }

  static String _firstBytesHex(File file) {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final length = file.lengthSync();
      final count = length >= 16 ? 16 : length;
      if (count <= 0) return '';
      final bytes = raf.readSync(count);
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } finally {
      raf.closeSync();
    }
  }
}
