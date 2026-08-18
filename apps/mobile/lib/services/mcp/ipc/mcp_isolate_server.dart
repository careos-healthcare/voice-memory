import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:archiveme_mobile/services/mcp/mcp_host.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// IPC envelope sent between MCP isolate client and server.
class McpIpcEnvelope {
  const McpIpcEnvelope({
    required this.requestId,
    required this.payload,
  });

  final int requestId;
  final String payload;

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'payload': payload,
  };

  factory McpIpcEnvelope.fromJson(Map<String, dynamic> json) {
    return McpIpcEnvelope(
      requestId: json['requestId'] as int? ?? 0,
      payload: json['payload'] as String? ?? '',
    );
  }
}

/// Startup message for the MCP worker isolate.
class McpIsolateStartup {
  const McpIsolateStartup({
    required this.handshakePort,
    required this.clientResponsePort,
    required this.prefsPath,
  });

  final SendPort handshakePort;
  final SendPort clientResponsePort;
  final String prefsPath;
}

/// Routes JSON-RPC payloads directly to an [McpHost] in-process.
class McpInProcessChannel {
  McpInProcessChannel(this._host);

  final McpHost _host;

  Future<String> send(String jsonPayload) => _host.handleJson(jsonPayload);

  McpHost get host => _host;
}

/// Client for the MCP worker isolate — JSON-RPC over SendPort/ReceivePort.
class McpIsolateChannel {
  McpIsolateChannel._({
    required this.serverPort,
    required ReceivePort responsePort,
    required StreamSubscription<dynamic> subscription,
    required Map<int, Completer<String>> pending,
  }) : _responsePort = responsePort,
       _subscription = subscription,
       _pending = pending;

  final SendPort serverPort;
  final ReceivePort _responsePort;
  final StreamSubscription<dynamic> _subscription;
  final Map<int, Completer<String>> _pending;
  int _nextRequestId = 1;

  /// Spawns a worker isolate with its own [McpHost] backed by [prefsPath].
  static Future<McpIsolateChannel> spawn({required String prefsPath}) async {
    final handshakePort = ReceivePort();
    final responsePort = ReceivePort();
    final pending = <int, Completer<String>>{};

    final subscription = responsePort.listen((message) {
      if (message is! Map) return;
      final envelope = McpIpcEnvelope.fromJson(
        message.map((key, value) => MapEntry(key.toString(), value)),
      );
      pending.remove(envelope.requestId)?.complete(envelope.payload);
    });

    await Isolate.spawn(
      _mcpIsolateEntry,
      McpIsolateStartup(
        handshakePort: handshakePort.sendPort,
        clientResponsePort: responsePort.sendPort,
        prefsPath: prefsPath,
      ),
    );

    final serverPort = await handshakePort.first;
    handshakePort.close();
    if (serverPort is! SendPort) {
      await subscription.cancel();
      responsePort.close();
      throw StateError('MCP isolate failed handshake.');
    }

    return McpIsolateChannel._(
      serverPort: serverPort,
      responsePort: responsePort,
      subscription: subscription,
      pending: pending,
    );
  }

  /// Sends a JSON-RPC payload and awaits the JSON response string.
  Future<String> send(String jsonPayload) async {
    final requestId = _nextRequestId++;
    final completer = Completer<String>();
    _pending[requestId] = completer;

    serverPort.send(
      McpIpcEnvelope(requestId: requestId, payload: jsonPayload).toJson(),
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(requestId);
        throw TimeoutException('MCP isolate response timed out.');
      },
    );
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    _responsePort.close();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('MCP isolate channel disposed.'));
      }
    }
    _pending.clear();
  }
}

Future<void> _mcpIsolateEntry(McpIsolateStartup startup) async {
  final prefs = await MobilePrefsStore.open(startup.prefsPath);
  final host = McpHost.fromPrefs(prefs);
  final serverPort = ReceivePort();
  startup.handshakePort.send(serverPort.sendPort);

  await for (final message in serverPort) {
    if (message is! Map) continue;
    final envelope = McpIpcEnvelope.fromJson(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );
    final responsePayload = await host.handleJson(envelope.payload);
    startup.clientResponsePort.send(
      McpIpcEnvelope(
        requestId: envelope.requestId,
        payload: responsePayload,
      ).toJson(),
    );
  }
}

/// Convenience helper decoding a JSON-RPC response map.
Map<String, dynamic> decodeMcpResponse(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('MCP response must be a JSON object.');
  }
  return decoded;
}
