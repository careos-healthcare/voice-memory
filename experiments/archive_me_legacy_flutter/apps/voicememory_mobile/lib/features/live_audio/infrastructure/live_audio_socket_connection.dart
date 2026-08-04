import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Minimal socket surface used by [LiveAudioWebSocketClient] for test injection.
abstract class LiveAudioSocketConnection {
  Stream<dynamic> get stream;
  Sink<dynamic> get sink;
  Future<void> get ready;
  Future<void> close([int? code, String? reason]);
}

class WebSocketLiveAudioSocketConnection implements LiveAudioSocketConnection {
  WebSocketLiveAudioSocketConnection(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  Sink<dynamic> get sink => _channel.sink;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Future<void> close([int? code, String? reason]) =>
      _channel.sink.close(code, reason);
}

typedef LiveAudioSocketConnectionFactory =
    LiveAudioSocketConnection Function(Uri uri, {Map<String, String>? headers});

LiveAudioSocketConnection defaultLiveAudioSocketConnection(
  Uri uri, {
  Map<String, String>? headers,
}) {
  return WebSocketLiveAudioSocketConnection(WebSocketChannel.connect(uri));
}
