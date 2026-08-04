import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisper_flutter_coreml/download_model.dart' show downloadModel;
import 'package:whisper_flutter_coreml/whisper_flutter_coreml.dart';

import '../../../storage/app_storage_paths.dart';

abstract interface class OnDeviceTranscriptionEngine {
  Future<bool> isReady();
  Future<void> prepare();
  Future<String> transcribe(File audioFile);
}

final class OnDeviceTranscriptionUnavailable implements Exception {
  const OnDeviceTranscriptionUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'OnDeviceTranscriptionUnavailable($reason)';
}

/// File-based Whisper transcription. Audio and model inference stay on-device.
///
/// The tiny multilingual model is downloaded only by [prepare], which callers
/// invoke while online. [transcribe] never initiates a download, ensuring an
/// offline capture cannot hang on a hidden network request.
final class WhisperOnDeviceTranscriptionEngine
    implements OnDeviceTranscriptionEngine {
  static const int _minimumCompleteModelBytes = 50 * 1024 * 1024;

  WhisperOnDeviceTranscriptionEngine({
    this._model = WhisperModel.tiny,
    this._language = 'auto',
    Future<Directory> Function()? modelDirectory,
  }) : _modelDirectory = modelDirectory ?? _defaultModelDirectory;

  final WhisperModel _model;
  final String _language;
  final Future<Directory> Function() _modelDirectory;
  Future<void>? _preparation;

  @override
  Future<bool> isReady() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    final directory = await _modelDirectory();
    final modelFile = File(_model.getPath(directory.path));
    return modelFile.existsSync() &&
        modelFile.lengthSync() >= _minimumCompleteModelBytes;
  }

  @override
  Future<void> prepare() {
    return _preparation ??= _prepareOnce().whenComplete(() {
      _preparation = null;
    });
  }

  Future<void> _prepareOnce() async {
    if (await isReady()) return;
    final directory = await _modelDirectory();
    await directory.create(recursive: true);
    await downloadModel(model: _model, destinationPath: directory.path);
    if (!await isReady()) {
      throw const OnDeviceTranscriptionUnavailable('model_download_incomplete');
    }
  }

  @override
  Future<String> transcribe(File audioFile) async {
    if (!await audioFile.exists()) {
      throw const OnDeviceTranscriptionUnavailable('audio_file_missing');
    }
    if (!audioFile.path.toLowerCase().endsWith('.wav')) {
      throw const OnDeviceTranscriptionUnavailable('unsupported_audio_format');
    }
    if (!await isReady()) {
      throw const OnDeviceTranscriptionUnavailable('model_not_ready');
    }

    final directory = await _modelDirectory();
    final whisper = Whisper(model: _model, modelDir: directory.path);
    final response = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: audioFile.path,
        language: _language,
        isNoTimestamps: true,
        threads: 4,
        nProcessors: 1,
      ),
    );
    final transcript = response.text.trim();
    if (transcript.isEmpty) {
      throw const OnDeviceTranscriptionUnavailable('empty_transcript');
    }
    return transcript;
  }

  static Future<Directory> _defaultModelDirectory() async {
    final support = await AppStoragePaths.applicationSupportDirectory();
    return Directory('${support.path}/offline_transcription');
  }
}
