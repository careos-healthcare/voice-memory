import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:whisper_flutter_coreml/download_model.dart' show WhisperModel;

import '../../services/analytics/ffi_safety_monitor.dart';
import '../../services/security/native_boundary_fuzzer.dart';
import '../voice_capture/transcription/on_device_transcription_engine.dart';

enum LocalWhisperModel { tinyEn, baseEn }

final class LocalWhisperException implements Exception {
  const LocalWhisperException(this.message);
  final String message;
  @override
  String toString() => 'LocalWhisperException: $message';
}

abstract interface class LocalWhisperDriver {
  Future<bool> isModelReady();
  Future<String> transcribe(File wavFile);
}

final class EmbeddedWhisperCppDriver implements LocalWhisperDriver {
  EmbeddedWhisperCppDriver({
    LocalWhisperModel model = LocalWhisperModel.tinyEn,
    OnDeviceTranscriptionEngine? engine,
  }) : _engine =
           engine ??
           WhisperOnDeviceTranscriptionEngine(
             model: model == LocalWhisperModel.baseEn
                 ? WhisperModel.base
                 : WhisperModel.tiny,
             language: 'en',
           );

  final OnDeviceTranscriptionEngine _engine;

  @override
  Future<bool> isModelReady() => _engine.isReady();

  @override
  Future<String> transcribe(File wavFile) => _engine.transcribe(wavFile);
}

final class WhisperAudioBuffer {
  WhisperAudioBuffer({required Uint8List wavBytes, required this.isFinal})
    : wavBytes = Uint8List.fromList(wavBytes);

  final Uint8List wavBytes;
  final bool isFinal;
}

final class LocalWhisperTranscript {
  const LocalWhisperTranscript({
    required this.text,
    required this.revision,
    required this.isFinal,
  });

  final String text;
  final int revision;
  final bool isFinal;
}

/// Strictly offline facade over the embedded whisper.cpp binding.
///
/// This class has no HTTP client and never invokes the model downloader.
/// Models must be provisioned before entering the air-gapped recorder flow.
final class LocalWhisperService {
  LocalWhisperService({
    LocalWhisperDriver? driver,
    this.model = LocalWhisperModel.tinyEn,
    Directory? scratchDirectory,
  }) : _driver = driver ?? EmbeddedWhisperCppDriver(model: model),
       _scratchDirectory =
           scratchDirectory ??
           Directory('${Directory.systemTemp.path}/whispering-vault');

  static const maximumWavBytes = 128 * 1024 * 1024;

  final LocalWhisperDriver _driver;
  final LocalWhisperModel model;
  final Directory _scratchDirectory;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> loadModel() async {
    if (!await _driver.isModelReady()) {
      throw const LocalWhisperException(
        'Offline Whisper model is not installed. Provision it before recording.',
      );
    }
    _loaded = true;
  }

  Future<String> transcribeFile(File wavFile) async {
    _ensureLoaded();
    if (!wavFile.existsSync() ||
        !wavFile.path.toLowerCase().endsWith('.wav') ||
        wavFile.lengthSync() < 44 ||
        wavFile.lengthSync() > maximumWavBytes ||
        !_hasWavFileHeader(wavFile)) {
      throw const LocalWhisperException('Invalid local WAV recording.');
    }
    final lease = FFISafetyMonitor.installed?.acquire(
      FFIResourceKind.whisperOperation,
      owner: 'whisper.cpp',
      estimatedBytes: wavFile.lengthSync(),
    );
    try {
      final transcript = (await _driver.transcribe(wavFile)).trim();
      if (transcript.isEmpty) {
        throw const LocalWhisperException(
          'Whisper returned an empty transcript.',
        );
      }
      return transcript;
    } finally {
      lease?.release();
    }
  }

  Future<String> transcribeBuffer(Uint8List wavBytes) async {
    _ensureLoaded();
    NativeBoundaryContract.requireBoundedBytes(
      wavBytes.length,
      maximum: maximumWavBytes,
    );
    if (wavBytes.length < 44 || !_hasWavHeader(wavBytes)) {
      throw const LocalWhisperException('Invalid WAV audio buffer.');
    }
    await _scratchDirectory.create(recursive: true);
    final file = File(
      '${_scratchDirectory.path}/${const Uuid().v4()}.working.wav',
    );
    final working = Uint8List.fromList(wavBytes);
    try {
      await file.writeAsBytes(working, flush: true);
      return await transcribeFile(file);
    } finally {
      working.fillRange(0, working.length, 0);
      if (file.existsSync()) file.deleteSync();
    }
  }

  Stream<LocalWhisperTranscript> transcribeStream(
    Stream<WhisperAudioBuffer> buffers,
  ) async* {
    _ensureLoaded();
    var revision = 0;
    var previous = '';
    await for (final buffer in buffers) {
      if (buffer.wavBytes.length < 44) continue;
      final transcript = await transcribeBuffer(buffer.wavBytes);
      if (transcript == previous && !buffer.isFinal) continue;
      previous = transcript;
      yield LocalWhisperTranscript(
        text: transcript,
        revision: ++revision,
        isFinal: buffer.isFinal,
      );
    }
  }

  void _ensureLoaded() {
    if (!_loaded) {
      throw const LocalWhisperException('Whisper model is not loaded.');
    }
  }

  static bool _hasWavHeader(List<int> bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45;

  static bool _hasWavFileHeader(File file) {
    final handle = file.openSync();
    try {
      return _hasWavHeader(handle.readSync(12));
    } finally {
      handle.closeSync();
    }
  }
}
