import 'dart:async';

import 'package:http/http.dart' as http;

import '../../api/api_transport.dart';
import '../sync/e2ee_sync_models.dart';
import '../sync/encrypted_sync_engine.dart';

final class CloudRelayTransportException implements Exception {
  const CloudRelayTransportException(
    this.message, {
    this.retryable = false,
    this.statusCode,
  });

  final String message;
  final bool retryable;
  final int? statusCode;

  @override
  String toString() => 'CloudRelayTransportException: $message';
}

final class CloudRelayDevicePresence {
  const CloudRelayDevicePresence({
    required this.id,
    required this.lastActiveAt,
  });

  final String id;
  final DateTime lastActiveAt;
}

abstract interface class CloudRelayDeviceDirectory {
  List<CloudRelayDevicePresence> get relayDevices;
  Stream<List<CloudRelayDevicePresence>> get relayDeviceChanges;
  Future<void> revokeRelayDevice(String deviceId);
}

final class CloudRelayApiTransport
    implements E2EERelayTransport, CloudRelayDeviceDirectory {
  CloudRelayApiTransport({
    required this.api,
    required this.deviceId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const route = '/api/sync-relay';

  final ApiTransport api;
  final String deviceId;
  final DateTime Function() _clock;
  final StreamController<List<CloudRelayDevicePresence>> _deviceChanges =
      StreamController<List<CloudRelayDevicePresence>>.broadcast();

  String? _token;
  DateTime? _tokenExpiresAt;
  Future<String>? _tokenRequest;
  List<CloudRelayDevicePresence> _devices = const [];

  @override
  List<CloudRelayDevicePresence> get relayDevices =>
      List.unmodifiable(_devices);

  @override
  Stream<List<CloudRelayDevicePresence>> get relayDeviceChanges =>
      _deviceChanges.stream;

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {
    if (envelope.deviceId != deviceId) {
      throw const CloudRelayTransportException(
        'Envelope device does not match relay identity.',
      );
    }
    await _authorizedRequest(
      (headers) => api.postJson(
        route,
        headers: headers,
        acceptedStatusCodes: const {202, 400, 401, 403, 413},
        body: {
          'action': 'push',
          'envelopes': [envelope.toRelayBlob()],
        },
      ),
      accepted: const {202},
    );
  }

  @override
  Future<List<E2EESyncEnvelope>> pull() async {
    final response = await _authorizedRequest(
      (headers) => api.get(
        route,
        headers: headers,
        acceptedStatusCodes: const {400, 401, 403, 413},
      ),
      accepted: const {200},
    );
    final body = api.decodeJson(response);
    _updateDevices(body['devices']);
    final raw = body['envelopes'];
    if (raw is! List) return const [];
    try {
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                E2EESyncEnvelope.fromRelayBlob(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on Object {
      throw const CloudRelayTransportException(
        'Relay returned an invalid opaque envelope.',
      );
    }
  }

  @override
  Future<void> revokeRelayDevice(String revokedDeviceId) async {
    final encoded = Uri.encodeQueryComponent(revokedDeviceId);
    await _authorizedRequest(
      (headers) => api.delete(
        '$route?deviceId=$encoded',
        headers: headers,
        acceptedStatusCodes: const {400, 401, 403},
      ),
      accepted: const {200},
    );
    _devices = _devices
        .where((device) => device.id != revokedDeviceId)
        .toList(growable: false);
    if (!_deviceChanges.isClosed) _deviceChanges.add(relayDevices);
  }

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required Set<int> accepted,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _requireToken(forceRefresh: attempt > 0);
      final response = await send({
        ...api.jsonHeaders,
        'Authorization': 'Bearer $token',
      });
      final status = response.statusCode;
      if (accepted.contains(status)) return response;
      if (status == 401 && attempt == 0) {
        _token = null;
        _tokenExpiresAt = null;
        continue;
      }
      throw CloudRelayTransportException(
        'Encrypted relay request failed.',
        statusCode: status,
        retryable: status == 408 || status == 429 || status >= 500,
      );
    }
    throw const CloudRelayTransportException(
      'Encrypted relay authentication failed.',
      statusCode: 401,
    );
  }

  Future<String> _requireToken({bool forceRefresh = false}) {
    final expiresAt = _tokenExpiresAt;
    if (!forceRefresh &&
        _token != null &&
        expiresAt != null &&
        expiresAt.isAfter(_clock().toUtc().add(const Duration(seconds: 30)))) {
      return Future.value(_token);
    }
    final active = _tokenRequest;
    if (!forceRefresh && active != null) return active;
    final request = _issueToken();
    _tokenRequest = request;
    return request.whenComplete(() {
      if (identical(_tokenRequest, request)) _tokenRequest = null;
    });
  }

  Future<String> _issueToken() async {
    final response = await api.postJson(
      route,
      acceptedStatusCodes: const {400, 401},
      body: {'action': 'issue_token', 'deviceId': deviceId},
    );
    if (response.statusCode != 200) {
      throw CloudRelayTransportException(
        'Sign in is required for encrypted relay sync.',
        statusCode: response.statusCode,
      );
    }
    final body = api.decodeJson(response);
    final token = body['token']?.toString();
    final expiresAt = DateTime.tryParse(body['expiresAt']?.toString() ?? '');
    if (token == null || token.isEmpty || expiresAt == null) {
      throw const CloudRelayTransportException(
        'Relay returned an invalid access token.',
      );
    }
    _token = token;
    _tokenExpiresAt = expiresAt.toUtc();
    return token;
  }

  void _updateDevices(Object? raw) {
    if (raw is! List) return;
    final parsed = <CloudRelayDevicePresence>[];
    for (final value in raw.whereType<Map>()) {
      final id = value['id']?.toString() ?? '';
      final timestamp = DateTime.tryParse(
        value['lastActiveAt']?.toString() ?? '',
      );
      if (id.isEmpty || timestamp == null) continue;
      parsed.add(
        CloudRelayDevicePresence(id: id, lastActiveAt: timestamp.toUtc()),
      );
    }
    parsed.sort((left, right) => left.id.compareTo(right.id));
    _devices = List.unmodifiable(parsed);
    if (!_deviceChanges.isClosed) _deviceChanges.add(relayDevices);
  }

  Future<void> dispose() => _deviceChanges.close();
}
