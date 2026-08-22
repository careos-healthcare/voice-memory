import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_socket_connection.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveAudioWebSocketClient', () {
    test(
      'connect appends sessionToken query param and waits for setupComplete',
      () async {
        Uri? capturedUri;
        final sinkController = StreamController<dynamic>();
        final client = LiveAudioWebSocketClient(
          connectionFactory: (uri, {headers}) {
            capturedUri = uri;
            return _FakeSocketConnection(sinkController);
          },
        );

        final config = LiveAudioSessionConfig(
          sessionId: 'session_1',
          sessionToken: 'token_abc',
          proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          model: 'gemini-2.5-flash-native-audio-preview-12-2025',
          inputAudioMimeType: liveInputAudioMime,
          outputAudioMimeType: liveOutputAudioMime,
        );

        final connectFuture = client.connect(config);
        await Future<void>.delayed(Duration.zero);
        await connectFuture;

        expect(
          capturedUri?.queryParameters[liveSessionTokenQueryParam],
          'token_abc',
        );
        expect(client.setupComplete, isFalse);

        sinkController.add(jsonEncode({'setupComplete': {}}));
        await Future<void>.delayed(Duration.zero);
        expect(client.setupComplete, isTrue);

        client.sendPcm16kChunk(const [1, 2, 3, 4]);
        await client.disconnect();
        await client.dispose();
        await sinkController.close();
      },
    );

    test('normalizes http proxy url to ws on connect', () async {
      Uri? capturedUri;
      final sinkController = StreamController<dynamic>();
      final client = LiveAudioWebSocketClient(
        connectionFactory: (uri, {headers}) {
          capturedUri = uri;
          return _FakeSocketConnection(sinkController);
        },
      );

      await client.connect(
        LiveAudioSessionConfig(
          sessionId: 'session_http',
          sessionToken: 'token',
          proxyWebSocketUrl: 'http://127.0.0.1:3000/api/live-audio/ws',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          model: 'gemini-2.5-flash-native-audio-preview-12-2025',
          inputAudioMimeType: liveInputAudioMime,
          outputAudioMimeType: liveOutputAudioMime,
        ),
      );

      expect(capturedUri?.scheme, 'ws');
      await client.dispose();
      await sinkController.close();
    });

    test('blocks audio before setupComplete', () async {
      final sinkController = StreamController<dynamic>();
      final client = LiveAudioWebSocketClient(
        connectionFactory: (_, {headers}) =>
            _FakeSocketConnection(sinkController),
      );

      await client.connect(
        LiveAudioSessionConfig(
          sessionId: 'session_2',
          sessionToken: 'token',
          proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          model: 'gemini-2.5-flash-native-audio-preview-12-2025',
          inputAudioMimeType: liveInputAudioMime,
          outputAudioMimeType: liveOutputAudioMime,
        ),
      );

      expect(
        () => client.sendPcm16kChunk(const [1]),
        throwsA(isA<StateError>()),
      );

      await client.dispose();
      await sinkController.close();
    });

    test('emits LiveSocketClosedEvent when stream closes', () async {
      final sinkController = StreamController<dynamic>();
      final client = LiveAudioWebSocketClient(
        connectionFactory: (_, {headers}) =>
            _FakeSocketConnection(sinkController),
      );

      await client.connect(
        LiveAudioSessionConfig(
          sessionId: 'session_close',
          sessionToken: 'token',
          proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          model: 'gemini-2.5-flash-native-audio-preview-12-2025',
          inputAudioMimeType: liveInputAudioMime,
          outputAudioMimeType: liveOutputAudioMime,
        ),
      );

      final events = <LiveServerEvent>[];
      final sub = client.serverEvents.listen(events.add);
      await sinkController.close();
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<LiveSocketClosedEvent>(), isNotEmpty);

      await sub.cancel();
      await client.dispose();
    });

    test('emits parsed server events', () async {
      final sinkController = StreamController<dynamic>();
      final client = LiveAudioWebSocketClient(
        connectionFactory: (_, {headers}) =>
            _FakeSocketConnection(sinkController),
      );

      await client.connect(
        LiveAudioSessionConfig(
          sessionId: 'session_3',
          sessionToken: 'token',
          proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          model: 'gemini-2.5-flash-native-audio-preview-12-2025',
          inputAudioMimeType: liveInputAudioMime,
          outputAudioMimeType: liveOutputAudioMime,
        ),
      );

      final events = <LiveServerEvent>[];
      final sub = client.serverEvents.listen(events.add);
      sinkController.add(jsonEncode({'setupComplete': {}}));
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<LiveSetupCompleteEvent>(), isNotEmpty);

      await sub.cancel();
      await client.dispose();
      await sinkController.close();
    });
  });
}

class _FakeSocketConnection implements LiveAudioSocketConnection {
  _FakeSocketConnection(this._events);

  final StreamController<dynamic> _events;

  @override
  Stream<dynamic> get stream => _events.stream;

  @override
  Sink<dynamic> get sink => _events.sink;

  @override
  Future<void> get ready => Future.value();

  @override
  Future<void> close([int? code, String? reason]) async {
    await _events.close();
  }
}