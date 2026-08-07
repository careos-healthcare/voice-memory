import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/core/network/http_transport.dart';
import 'package:voicememory_mobile/core/network/multipart_file_part.dart';
import 'package:voicememory_mobile/core/network/network_cancel_token.dart';

void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

  group('HttpTransport.postMultipart', () {
    test('uploads fields and bytes with injected headers', () async {
      http.BaseRequest? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      });
      final transport = HttpTransport(
        client: client,
        baseUrl: 'http://test.invalid',
      );
      addTearDown(transport.dispose);

      final result = await transport.postMultipart(
        '/api/transcribe',
        fields: {'durationSeconds': '5'},
        files: [
          MultipartFilePart.fromBytes(
            field: 'audio',
            bytes: [1, 2, 3],
            filename: 'clip.m4a',
            contentType: MediaType('audio', 'mp4'),
          ),
        ],
        headers: {'x-vm-capture-token': 'capture-token'},
      );

      expect(result.isSuccess, isTrue);
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/transcribe');
      expect(
        captured!.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(captured!.headers['x-vm-capture-token'], 'capture-token');
      expect(captured!.headers['Accept'], 'application/json');
    });

    test('supports stream file parts', () async {
      final client = MockClient((request) async {
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        return http.Response('{"ok":true}', 200);
      });
      final transport = HttpTransport(
        client: client,
        baseUrl: 'http://test.invalid',
      );
      addTearDown(transport.dispose);

      final result = await transport.postMultipart(
        '/api/live-audio/recover',
        files: [
          MultipartFilePart.fromStream(
            field: 'vault',
            stream: Stream<List<int>>.value([9, 8, 7, 6]),
            length: 4,
            filename: 'vault.bin',
            contentType: MediaType('application', 'octet-stream'),
          ),
        ],
      );

      expect(result.isSuccess, isTrue);
    });

    test('supports path file parts', () async {
      final tempDir = await Directory.systemTemp.createTemp('multipart_path_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final file = File('${tempDir.path}/audio.m4a');
      await file.writeAsBytes([10, 11, 12]);

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        return http.Response('{"ok":true}', 200);
      });
      final transport = HttpTransport(
        client: client,
        baseUrl: 'http://test.invalid',
      );
      addTearDown(transport.dispose);

      final result = await transport.postMultipart(
        '/api/transcribe',
        files: [
          MultipartFilePart.fromPath(
            field: 'audio',
            path: file.path,
            filename: 'audio.m4a',
          ),
        ],
      );

      expect(result.isSuccess, isTrue);
    });

    test('returns ApiFailureCancelled when token is cancelled', () async {
      final token = NetworkCancelToken()..cancel();
      final transport = HttpTransport(baseUrl: 'http://test.invalid');
      addTearDown(transport.dispose);

      final result = await transport.postMultipart(
        '/api/transcribe',
        cancelToken: token,
      );

      expect(result.failureOrNull, isA<ApiFailureCancelled>());
    });

    test('maps socket failures to ApiFailureOffline', () async {
      final client = MockClient((_) async {
        throw const SocketException('Connection refused');
      });
      final transport = HttpTransport(
        client: client,
        baseUrl: 'http://test.invalid',
      );
      addTearDown(transport.dispose);

      final result = await transport.postMultipart('/api/transcribe');

      expect(result.failureOrNull, isA<ApiFailureOffline>());
    });
  });
}
