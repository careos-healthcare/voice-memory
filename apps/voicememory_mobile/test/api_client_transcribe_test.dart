import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/core/network/http_transport.dart';
import 'package:voicememory_mobile/data/network/http_capture_api_client.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:voicememory_mobile/security/api_response_safety.dart';

void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

  test(
    'postTranscribe rejects HTML responses with clear fallback reason',
    () async {
      final transport = HttpTransport(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://voice-memory-iota.vercel.app/api/transcribe',
          );
          expect(request.method, 'POST');
          expect(request.headers['x-vm-capture-token'], 'capture-token');
          expect(request.headers['accept'], 'application/json');
          return http.Response(
            '<!DOCTYPE html><html><body>404</body></html>',
            404,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
        baseUrl: 'https://voice-memory-iota.vercel.app',
      );
      final client = HttpCaptureApiClient(transport);

      final dir = Directory.systemTemp.createTempSync('vm_transcribe_html_');
      final audio = File('${dir.path}/voice.m4a')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      final result = await client.postTranscribe(
        audioFile: audio,
        durationSeconds: 12,
        captureToken: 'capture-token',
      );

      expect(
        result.when(
          success: (_) => null,
          onFailure: (failure) => failure.toApiException(),
        ),
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          ApiResponseSafety.htmlResponseMessage,
        ),
      );

      expect(
        TranscriptionService.failureReason(
          FormatException(ApiResponseSafety.htmlResponseMessage),
        ),
        'wrong_api_host:html_response',
      );
    },
  );

  test('postTranscribe parses JSON transcript on success', () async {
    final transport = HttpTransport(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'transcript': 'Hello from the server.'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://voice-memory-iota.vercel.app',
    );
    final client = HttpCaptureApiClient(transport);

    final dir = Directory.systemTemp.createTempSync('vm_transcribe_ok_');
    final audio = File('${dir.path}/voice.m4a')
      ..writeAsBytesSync(const [1, 2, 3, 4]);

    final result = await client.postTranscribe(
      audioFile: audio,
      durationSeconds: 12,
      captureToken: 'capture-token',
    );

    final transcript = result.when(
      success: (value) => value,
      onFailure: (failure) => throw failure.toApiException(),
    );

    expect(transcript, 'Hello from the server.');
  });
}
