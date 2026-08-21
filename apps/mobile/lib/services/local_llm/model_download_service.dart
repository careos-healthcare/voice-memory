import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/services/local_llm/local_llm_model_contract.dart';
import 'package:archiveme_mobile/services/local_llm/model_download_contract.dart';
import 'package:archiveme_mobile/services/local_llm/model_download_progress.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Downloads the mobile GGUF model into [getApplicationDocumentsDirectory]
/// on first launch and exposes progress to the UI isolate.
final class ModelDownloadService {
  ModelDownloadService({
    Dio? dio,
    String? remoteModelUrl,
    Future<Directory> Function()? documentsDirectory,
  })  : _dio = dio ?? Dio(),
        _remoteModelUrl = ModelDownloadContract.remoteModelUrl(
          override: remoteModelUrl,
        ),
        _documentsDirectory =
            documentsDirectory ?? AppStoragePaths.applicationDocumentsDirectory;

  final Dio _dio;
  final String _remoteModelUrl;
  final Future<Directory> Function() _documentsDirectory;

  final StreamController<ModelDownloadProgress> _progressController =
      StreamController<ModelDownloadProgress>.broadcast();

  ModelDownloadProgress _currentProgress = const ModelDownloadProgress.idle();
  Future<String?>? _ensureFuture;

  /// Broadcast progress for UI widgets on the main isolate.
  Stream<ModelDownloadProgress> get progressStream =>
      _progressController.stream;

  ModelDownloadProgress get currentProgress => _currentProgress;

  /// Resolved on-disk GGUF path under app documents, or null when absent.
  Future<String?> modelFilePath() async {
    final file = await _modelFile();
    if (!await file.exists()) return null;
    if (await file.length() <= 0) return null;
    if (!LocalLlmModelContract.isHeavilyQuantizedGguf(file.path)) {
      return null;
    }
    return file.path;
  }

  Future<bool> isModelInstalled() async => (await modelFilePath()) != null;

  /// Ensures the GGUF exists locally. Downloads once on first launch when missing.
  Future<String?> ensureModelDownloaded() {
    return _ensureFuture ??= _ensureModelDownloadedImpl().whenComplete(() {
      _ensureFuture = null;
    });
  }

  /// Deletes the downloaded model to reclaim local storage.
  Future<void> deleteModel() async {
    final file = await _modelFile();
    if (await file.exists()) {
      await file.delete();
    }

    final partial = File('${file.path}.part');
    if (await partial.exists()) {
      await partial.delete();
    }

    _emit(const ModelDownloadProgress.deleted());
  }

  Future<String?> _ensureModelDownloadedImpl() async {
    final existing = await modelFilePath();
    if (existing != null) {
      final bytes = await File(existing).length();
      _emit(
        ModelDownloadProgress(
          phase: ModelDownloadPhase.completed,
          modelPath: existing,
          receivedBytes: bytes,
          totalBytes: bytes,
        ),
      );
      return existing;
    }

    return _downloadModel();
  }

  Future<String?> _downloadModel() async {
    final destination = await _modelFile();
    await destination.parent.create(recursive: true);

    final partial = File('${destination.path}.part');
    if (await partial.exists()) {
      await partial.delete();
    }

    _emit(
      const ModelDownloadProgress(
        phase: ModelDownloadPhase.downloading,
        receivedBytes: 0,
      ),
    );

    try {
      await _dio.download(
        _remoteModelUrl,
        partial.path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          _emit(
            ModelDownloadProgress(
              phase: ModelDownloadPhase.downloading,
              receivedBytes: received,
              totalBytes: total > 0 ? total : null,
            ),
          );
        },
      );

      if (await partial.exists()) {
        await partial.rename(destination.path);
      }

      if (!LocalLlmModelContract.isHeavilyQuantizedGguf(destination.path)) {
        throw ModelDownloadException(
          'Downloaded file is not a supported quantized GGUF.',
        );
      }

      final bytes = await destination.length();
      _emit(
        ModelDownloadProgress(
          phase: ModelDownloadPhase.completed,
          modelPath: destination.path,
          receivedBytes: bytes,
          totalBytes: bytes,
        ),
      );
      return destination.path;
    } on Object catch (error, stackTrace) {
      if (await partial.exists()) {
        await partial.delete();
      }
      _emit(
        ModelDownloadProgress(
          phase: ModelDownloadPhase.failed,
          errorMessage: error.toString(),
        ),
      );
      return null;
    }
  }

  Future<File> _modelFile() async {
    final docs = await _documentsDirectory();
    return File(
      p.join(
        docs.path,
        LocalLlmModelContract.sideloadDirectoryName,
        LocalLlmModelContract.sideloadModelFileName,
      ),
    );
  }

  void _emit(ModelDownloadProgress progress) {
    _currentProgress = progress;
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  Future<void> dispose() async {
    await _progressController.close();
  }
}

/// Raised when a remote model download fails validation or transport.
final class ModelDownloadException implements Exception {
  ModelDownloadException(this.message);

  final String message;

  @override
  String toString() => 'ModelDownloadException: $message';
}