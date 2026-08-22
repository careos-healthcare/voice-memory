import 'dart:io';

import 'package:archiveme_mobile/services/local_llm/model_download_progress.dart';
import 'package:archiveme_mobile/services/local_llm/model_download_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ModelDownloadService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('model_download_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('ensureModelDownloaded skips download when model already exists', () async {
      final modelDir = Directory(p.join(tempDir.path, 'local_llm'));
      await modelDir.create(recursive: true);
      final modelFile = File(
        p.join(modelDir.path, 'model-q4_k_m.gguf'),
      );
      await modelFile.writeAsBytes(List.filled(32, 0));

      var downloadCalls = 0;
      final service = ModelDownloadService(
        documentsDirectory: () async => tempDir,
        dio: _FakeDio(onDownload: () {
          downloadCalls++;
        }),
      );

      final path = await service.ensureModelDownloaded();

      expect(path, isNotNull);
      expect(downloadCalls, 0);
      expect(await service.isModelInstalled(), isTrue);
    });

    test('ensureModelDownloaded emits progress and writes model file', () async {
      final service = ModelDownloadService(
        documentsDirectory: () async => tempDir,
        dio: _FakeDio(
          payload: List<int>.generate(128, (index) => index),
        ),
      );

      final progressPhases = <ModelDownloadPhase>[];
      final sub = service.progressStream.listen(
        (event) => progressPhases.add(event.phase),
      );

      final path = await service.ensureModelDownloaded();
      await sub.cancel();

      expect(path, isNotNull);
      expect(progressPhases, contains(ModelDownloadPhase.downloading));
      expect(service.currentProgress.phase, ModelDownloadPhase.completed);
      expect(File(path!).lengthSync(), 128);
    });

    test('deleteModel removes downloaded file and emits deleted progress', () async {
      final service = ModelDownloadService(
        documentsDirectory: () async => tempDir,
        dio: _FakeDio(payload: const [1, 2, 3, 4]),
      );

      final path = await service.ensureModelDownloaded();
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);

      await service.deleteModel();

      expect(service.currentProgress.phase, ModelDownloadPhase.deleted);
      expect(await service.isModelInstalled(), isFalse);
    });

    test('ensureModelDownloaded is idempotent while in flight', () async {
      final service = ModelDownloadService(
        documentsDirectory: () async => tempDir,
        dio: _SlowFakeDio(payload: const [9, 8, 7]),
      );

      final first = service.ensureModelDownloaded();
      final second = service.ensureModelDownloaded();

      final results = await Future.wait([first, second]);
      expect(results[0], results[1]);
      expect(await service.isModelInstalled(), isTrue);
    });
  });
}

final class _FakeDio implements Dio {
  _FakeDio({
    this.payload = const [],
    this.onDownload,
  });

  final List<int> payload;
  final void Function()? onDownload;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Response<dynamic>> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    FileAccessMode fileAccessMode = FileAccessMode.write,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
  }) async {
    onDownload?.call();
    onReceiveProgress?.call(0, payload.length);
    await File(savePath as String).writeAsBytes(payload);
    onReceiveProgress?.call(payload.length, payload.length);
    return Response(requestOptions: RequestOptions(path: urlPath));
  }
}

final class _SlowFakeDio extends _FakeDio {
  _SlowFakeDio({super.payload});

  @override
  Future<Response<dynamic>> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    FileAccessMode fileAccessMode = FileAccessMode.write,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
  }) async {
    onReceiveProgress?.call(0, payload.length);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await File(savePath as String).writeAsBytes(payload);
    onReceiveProgress?.call(payload.length, payload.length);
    return Response(requestOptions: RequestOptions(path: urlPath));
  }
}
