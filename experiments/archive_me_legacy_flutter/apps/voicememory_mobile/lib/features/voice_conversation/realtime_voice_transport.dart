import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'realtime_session_config.dart';

abstract interface class RealtimeVoiceTransport {
  Stream<Map<String, dynamic>> get events;
  Future<void> connect(RealtimeSessionConfig config);
  void send(Map<String, dynamic> event);
  Future<void> disconnect();
}

class OpenAiRealtimeWebSocketTransport implements RealtimeVoiceTransport {
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<void> connect(RealtimeSessionConfig config) async {
    await disconnect();
    final socket = await WebSocket.connect(
      config.realtimeWebSocketUrl.toString(),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${config.clientSecret}',
        'OpenAI-Beta': 'realtime=v1',
      },
    );
    _socket = socket;
    _subscription = socket.listen(
      (message) {
        if (message is! String) return;
        final decoded = jsonDecode(message);
        if (decoded is Map && !_events.isClosed) {
          _events.add(Map<String, dynamic>.from(decoded));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_events.isClosed) _events.addError(error, stackTrace);
      },
      onDone: () {
        if (!_events.isClosed) {
          _events.add(const {'type': 'transport.disconnected'});
        }
      },
    );
  }

  @override
  void send(Map<String, dynamic> event) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('Realtime transport is not connected.');
    }
    socket.add(jsonEncode(event));
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    await socket?.close(WebSocketStatus.normalClosure);
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
