import 'dart:async';
import 'dart:convert';

import '../domain/models/live_audio_session_config.dart';
import '../domain/models/live_server_event.dart';
import '../domain/services/live_audio_protocol.dart';
import '../domain/services/live_proxy_url.dart';
import '../live_audio_constants.dart';
import 'live_audio_pipeline_log.dart';
import 'live_audio_socket_connection.dart';

/// Backend-proxy WebSocket client — never connects directly to Google.
class LiveAudioWebSocketClient {
  LiveAudioWebSocketClient({
    LiveAudioSocketConnectionFactory? connectionFactory,
  }) : _connectionFactory =
           connectionFactory ?? defaultLiveAudioSocketConnection;

  final LiveAudioSocketConnectionFactory _connectionFactory;

  LiveAudioSocketConnection? _connection;
  StreamSubscription<dynamic>? _subscription;
  LiveAudioSessionConfig? _activeConfig;
  var _setupComplete = false;
  final _serverEventsController = StreamController<LiveServerEvent>.broadcast();

  Stream<LiveServerEvent> get serverEvents => _serverEventsController.stream;

  bool get isConnected => _connection != null;

  bool get setupComplete => _setupComplete;

  LiveAudioSessionConfig? get activeConfig => _activeConfig;

  Future<void> connect(LiveAudioSessionConfig config) async {
    if (_connection != null) {
      throw StateError('LiveAudioWebSocketClient already connected');
    }
    if (config.isExpired) {
      throw StateError('Live audio session token expired before connect');
    }

    _activeConfig = config;
    _setupComplete = false;

    final uri = _buildProxyUri(config);
    LiveAudioPipelineLog.connectStarted(
      sessionId: config.sessionId,
      proxyWebSocketUrl: uri.toString(),
    );

    _connection = _connectionFactory(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    await _connection!.ready;

    _subscription = _connection!.stream.listen(
      _handleRawMessage,
      onError: (Object error, StackTrace stackTrace) {
        LiveAudioPipelineLog.failure('websocket_stream', error);
        if (!_serverEventsController.isClosed) {
          _serverEventsController.add(
            LiveServerErrorEvent(message: error.toString()),
          );
        }
      },
      onDone: () {
        LiveAudioPipelineLog.disconnect(
          sessionId: config.sessionId,
          reason: 'socket_closed',
        );
        if (!_serverEventsController.isClosed) {
          _serverEventsController.add(
            const LiveSocketClosedEvent(reason: 'socket_closed'),
          );
        }
      },
      cancelOnError: false,
    );
  }

  void sendPcm16kChunk(List<int> pcm16kBytes) {
    _ensureReadyForInput();
    final message = LiveAudioProtocol.buildAudioInputMessage(pcm16kBytes);
    final validation = LiveAudioProtocol.validateClientMessage(message);
    if (!validation.ok) {
      throw StateError('Invalid audio input frame: ${validation.reason}');
    }
    _connection!.sink.add(LiveAudioProtocol.encodeClientMessage(message));
  }

  void sendAudioStreamEnd() {
    _ensureReadyForInput();
    final message = LiveAudioProtocol.buildAudioStreamEndMessage();
    _connection!.sink.add(LiveAudioProtocol.encodeClientMessage(message));
  }

  Future<void> disconnect({String reason = 'client_disconnect'}) async {
    final sessionId = _activeConfig?.sessionId;
    await _subscription?.cancel();
    _subscription = null;
    await _connection?.close();
    _connection = null;
    _setupComplete = false;
    _activeConfig = null;
    if (sessionId != null) {
      LiveAudioPipelineLog.disconnect(sessionId: sessionId, reason: reason);
    }
  }

  Future<void> dispose() async {
    await disconnect(reason: 'dispose');
    await _serverEventsController.close();
  }

  Uri _buildProxyUri(LiveAudioSessionConfig config) {
    final base = Uri.parse(
      normalizeProxyWebSocketUrl(config.proxyWebSocketUrl),
    );
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        liveSessionTokenQueryParam: config.sessionToken,
      },
    );
  }

  void _handleRawMessage(dynamic rawMessage) {
    final jsonString = switch (rawMessage) {
      String value => value,
      List<int> value => utf8.decode(value),
      _ => jsonEncode(rawMessage),
    };

    for (final event in LiveAudioProtocol.parseServerJson(jsonString)) {
      if (event is LiveSetupCompleteEvent) {
        _setupComplete = true;
        final sessionId = _activeConfig?.sessionId;
        if (sessionId != null) {
          LiveAudioPipelineLog.setupComplete(sessionId: sessionId);
        }
      }
      if (!_serverEventsController.isClosed) {
        _serverEventsController.add(event);
      }
    }
  }

  void _ensureReadyForInput() {
    if (_connection == null) {
      throw StateError('Live audio websocket is not connected');
    }
    if (!_setupComplete) {
      throw StateError('Cannot stream audio before setupComplete');
    }
  }
}
