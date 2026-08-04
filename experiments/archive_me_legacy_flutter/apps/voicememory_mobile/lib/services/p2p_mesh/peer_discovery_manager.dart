import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../features/p2p_mesh/mesh_discovery_service.dart';
import '../../features/p2p_mesh/mesh_models.dart';
import '../../features/p2p_mesh/mesh_secure_session.dart';

enum SovereignPeerTransport { mdns, ble }

final class SovereignPeer {
  SovereignPeer({
    required this.id,
    required this.displayName,
    required Iterable<SovereignPeerTransport> transports,
    this.mdnsPeer,
    this.bleRemoteId,
    this.rssi,
  }) : transports = Set.unmodifiable(transports);

  final String id;
  final String displayName;
  final Set<SovereignPeerTransport> transports;
  final MeshPeer? mdnsPeer;
  final String? bleRemoteId;
  final int? rssi;

  SovereignPeer merge(SovereignPeer other) => SovereignPeer(
    id: id,
    displayName: mdnsPeer != null ? displayName : other.displayName,
    transports: {...transports, ...other.transports},
    mdnsPeer: mdnsPeer ?? other.mdnsPeer,
    bleRemoteId: bleRemoteId ?? other.bleRemoteId,
    rssi: other.rssi ?? rssi,
  );
}

final class BlePeerBeacon {
  const BlePeerBeacon({
    required this.peerId,
    required this.remoteId,
    required this.rssi,
  });

  final String peerId;
  final String remoteId;
  final int rssi;
}

abstract interface class BlePeerDiscoveryBackend {
  Stream<BlePeerBeacon> get beacons;
  Future<void> start({required String peerId});
  Future<void> stop();
  Future<void> dispose();
}

final class FlutterBlePeerDiscoveryBackend implements BlePeerDiscoveryBackend {
  FlutterBlePeerDiscoveryBackend({FlutterBlePeripheral? peripheral})
    : _peripheral = peripheral ?? FlutterBlePeripheral();

  static const serviceUuid = '7b4e0001-7e42-4b6f-9a72-617263686976';
  final FlutterBlePeripheral _peripheral;
  final StreamController<BlePeerBeacon> _beacons =
      StreamController<BlePeerBeacon>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _started = false;

  @override
  Stream<BlePeerBeacon> get beacons => _beacons.stream;

  @override
  Future<void> start({required String peerId}) async {
    if (_started) return;
    _started = true;
    final bytes = _opaqueIdBytes(peerId);
    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      _onScanResults,
      onError: _beacons.addError,
    );
    try {
      if (await _peripheral.isSupported) {
        await _peripheral.requestPermission();
        await _peripheral.start(
          advertiseData: AdvertiseData(
            serviceUuids: const [serviceUuid],
            serviceDataUuid: serviceUuid,
            serviceData: bytes,
            manufacturerId: 0xFFFF,
            manufacturerData: Uint8List.fromList(bytes),
            localName: 'ArchiveMe Mesh',
          ),
        );
      }
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 12),
      );
    } on Object {
      _started = false;
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      rethrow;
    }
  }

  void _onScanResults(List<ScanResult> results) {
    final uuid = Guid(serviceUuid);
    for (final result in results) {
      final advertisement = result.advertisementData;
      final data =
          advertisement.serviceData[uuid] ??
          advertisement.manufacturerData[0xFFFF];
      final remoteId = result.device.remoteId.str;
      final peerId = data == null || data.isEmpty
          ? 'ble:$remoteId'
          : _opaqueId(data);
      _beacons.add(
        BlePeerBeacon(peerId: peerId, remoteId: remoteId, rssi: result.rssi),
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await FlutterBluePlus.stopScan();
    await _peripheral.stop();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _beacons.close();
  }
}

final class AuthenticatedMeshSession {
  const AuthenticatedMeshSession(this.pending);

  final MeshPendingSession pending;
  String get peerId => pending.remoteDeviceId;
  String get verifiedFingerprint => pending.remoteFingerprint;
  String get shortAuthenticationString => pending.sas;
}

final class PeerDiscoveryManager {
  PeerDiscoveryManager({required this.mdns, required this.ble});

  final MeshDiscoveryService mdns;
  final BlePeerDiscoveryBackend ble;
  final StreamController<List<SovereignPeer>> _peers =
      StreamController<List<SovereignPeer>>.broadcast();
  final Map<String, SovereignPeer> _nearby = {};
  StreamSubscription<List<MeshPeer>>? _mdnsSubscription;
  StreamSubscription<BlePeerBeacon>? _bleSubscription;
  bool _started = false;

  Stream<List<SovereignPeer>> get peers => _peers.stream;
  List<SovereignPeer> get currentPeers => List.unmodifiable(_sortedPeers());

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _mdnsSubscription ??= mdns.peers.listen(_onMdnsPeers);
    _bleSubscription ??= ble.beacons.listen(_onBleBeacon);
    try {
      await mdns.start();
      final serviceId = mdns.currentServiceId;
      if (serviceId == null) {
        throw StateError('mDNS did not establish a rotating service id.');
      }
      await ble.start(peerId: serviceId);
    } on Object {
      _started = false;
      await mdns.stop();
      await ble.stop();
      rethrow;
    }
  }

  Future<AuthenticatedMeshSession> establishAuthenticatedSession(
    SovereignPeer peer, {
    MeshPairingInvitation? invitation,
  }) async {
    final endpoint = peer.mdnsPeer;
    if (endpoint == null) {
      throw StateError(
        'BLE located this peer, but a local IP endpoint is not available yet.',
      );
    }
    final connection = await mdns.connect(endpoint);
    try {
      final pending = await MeshHandshake.initiate(
        connection: connection,
        identity: mdns.identity,
        invitation: invitation,
      );
      final advertised = endpoint.identityFingerprint;
      if (advertised.isNotEmpty && advertised != pending.remoteFingerprint) {
        await pending.session.close();
        throw StateError('Mesh peer identity verification failed.');
      }
      return AuthenticatedMeshSession(pending);
    } on Object {
      await connection.close();
      rethrow;
    }
  }

  void _onMdnsPeers(List<MeshPeer> values) {
    final active = values.map((peer) => peer.id).toSet();
    _nearby.removeWhere(
      (id, peer) =>
          peer.transports.length == 1 &&
          peer.transports.contains(SovereignPeerTransport.mdns) &&
          !active.contains(id),
    );
    for (final peer in values) {
      _put(
        SovereignPeer(
          id: peer.id,
          displayName: peer.name,
          transports: const [SovereignPeerTransport.mdns],
          mdnsPeer: peer,
        ),
      );
    }
    _emit();
  }

  void _onBleBeacon(BlePeerBeacon beacon) {
    _put(
      SovereignPeer(
        id: beacon.peerId,
        displayName: 'Nearby ArchiveMe device',
        transports: const [SovereignPeerTransport.ble],
        bleRemoteId: beacon.remoteId,
        rssi: beacon.rssi,
      ),
    );
    _emit();
  }

  void _put(SovereignPeer peer) {
    _nearby.update(
      peer.id,
      (current) => current.merge(peer),
      ifAbsent: () => peer,
    );
  }

  List<SovereignPeer> _sortedPeers() =>
      _nearby.values.toList()
        ..sort((left, right) => left.id.compareTo(right.id));

  void _emit() => _peers.add(List.unmodifiable(_sortedPeers()));

  Future<void> stop() async {
    _started = false;
    await Future.wait([mdns.stop(), ble.stop()]);
    _nearby.clear();
    _emit();
  }

  Future<void> dispose() async {
    await stop();
    await _mdnsSubscription?.cancel();
    await _bleSubscription?.cancel();
    await ble.dispose();
    await _peers.close();
  }
}

List<int> _opaqueIdBytes(String value) {
  final clean = value.replaceAll(RegExp('[^0-9a-fA-F]'), '');
  if (clean.length >= 24) {
    return [
      for (var index = 0; index < 24; index += 2)
        int.parse(clean.substring(index, index + 2), radix: 16),
    ];
  }
  return utf8.encode(value).take(12).toList(growable: false);
}

String _opaqueId(List<int> bytes) => bytes
    .take(12)
    .map((value) => value.toRadixString(16).padLeft(2, '0'))
    .join();
