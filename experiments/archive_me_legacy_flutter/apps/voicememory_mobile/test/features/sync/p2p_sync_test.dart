import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_discovery.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_models.dart';
import 'package:voicememory_mobile/features/sync/models/sync_conflict_resolution.dart';
import 'package:voicememory_mobile/features/sync/services/p2p_mesh_service.dart';
import 'package:voicememory_mobile/features/sync/services/sync_coordinator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/journal_sync_metadata.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  test('LWW keeps the entry with the newest updatedAt timestamp', () {
    final local = _entry(
      transcript: 'local',
      updatedAt: DateTime.utc(2026, 7, 29, 10),
      deviceId: 'local-device',
    );
    final remote = _entry(
      transcript: 'remote',
      updatedAt: DateTime.utc(2026, 7, 29, 11),
      deviceId: 'remote-device',
    );

    final winner = SyncConflictResolution.resolve(local: local, remote: remote);

    expect(winner.transcript, 'remote');
  });

  test('discovers, connects, broadcasts, and receives journal JSON', () async {
    final adapter = _FakeMeshAdapter();
    final service = P2PMeshService(adapter: adapter, deviceId: 'local-device');
    await service.startDiscovery();
    expect(adapter.advertised, isTrue);
    expect(adapter.discoveryStarted, isTrue);

    final peer = MeshPeer(
      id: 'remote-device',
      name: 'Remote',
      host: '192.168.1.4',
      port: 4321,
      identityFingerprint: '',
    );
    adapter.peerEventsController.add(
      MeshPeerEvent(kind: MeshPeerEventKind.found, peer: peer),
    );
    await Future<void>.delayed(Duration.zero);
    expect(service.nearbyPeers.single.id, 'remote-device');

    await service.connectToPeer(peer);
    await service.broadcastEntry({'id': 'entry-1', 'transcript': 'hello'});
    final sentPackets = adapter.outgoing.sent.map(_decodePacket).toList();
    expect(sentPackets.first['type'], 'hello');
    expect(sentPackets.last['type'], 'journal_entry');

    final receivedFuture = service.receivedEntries.first;
    adapter.outgoing.push({
      'version': 1,
      'type': 'hello',
      'sourceDeviceId': 'remote-device',
    });
    adapter.outgoing.push({
      'version': 1,
      'type': 'journal_entry',
      'sourceDeviceId': 'remote-device',
      'entry': {'id': 'entry-2', 'transcript': 'from peer'},
    });
    expect(await receivedFuture, containsPair('id', 'entry-2'));

    await service.dispose();
  });

  test(
    'coordinator broadcasts local changes and applies newer peers',
    () async {
      final adapter = _FakeMeshAdapter();
      final service = P2PMeshService(
        adapter: adapter,
        deviceId: 'local-device',
      );
      await service.startDiscovery();
      final peer = MeshPeer(
        id: 'remote-device',
        name: 'Remote',
        host: '192.168.1.4',
        port: 4321,
        identityFingerprint: '',
      );
      await service.connectToPeer(peer);

      final store = _FakeJournalStore();
      final coordinator = SyncCoordinator(
        journalStore: store,
        meshService: service,
      )..start();
      await Future<void>.delayed(Duration.zero);

      final local = _entry(
        transcript: 'local version',
        updatedAt: DateTime.utc(2026, 7, 29, 10),
        deviceId: 'local-device',
      );
      store.emit([local]);
      await _waitFor(
        () => adapter.outgoing.sent
            .map(_decodePacket)
            .any((packet) => packet['type'] == 'journal_entry'),
      );

      final remote = _entry(
        transcript: 'newer remote version',
        updatedAt: DateTime.utc(2026, 7, 29, 12),
        deviceId: 'remote-device',
      );
      adapter.outgoing.push({
        'version': 1,
        'type': 'hello',
        'sourceDeviceId': 'remote-device',
      });
      adapter.outgoing.push({
        'version': 1,
        'type': 'journal_entry',
        'sourceDeviceId': 'remote-device',
        'entry': remote.toJson(includeLocalContext: false),
      });
      await _waitFor(
        () => store.entries.single.transcript == 'newer remote version',
      );

      await coordinator.stop();
      await service.dispose();
      await store.close();
    },
  );
}

class _FakeMeshAdapter implements MeshDiscoveryAdapter {
  final StreamController<MeshPeerEvent> peerEventsController =
      StreamController<MeshPeerEvent>.broadcast();
  final StreamController<MeshConnection> incomingController =
      StreamController<MeshConnection>.broadcast();
  final _FakeMeshConnection outgoing = _FakeMeshConnection();
  bool advertised = false;
  bool discoveryStarted = false;

  @override
  Stream<MeshPeerEvent> get peerEvents => peerEventsController.stream;

  @override
  Stream<MeshConnection> get incomingConnections => incomingController.stream;

  @override
  Future<int> advertise(MeshAdvertisement advertisement) async {
    advertised = true;
    return 4321;
  }

  @override
  Future<void> startDiscovery({String? excludePeerId}) async {
    discoveryStarted = true;
  }

  @override
  Future<MeshConnection> connect(
    MeshPeer peer, {
    Duration timeout = const Duration(seconds: 10),
  }) async => outgoing;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await peerEventsController.close();
    await incomingController.close();
    await outgoing.close();
  }
}

class _FakeMeshConnection implements MeshConnection {
  final StreamController<List<int>> _bytes =
      StreamController<List<int>>.broadcast();
  final List<List<int>> sent = [];
  bool _closed = false;

  @override
  String get remoteAddress => '192.168.1.4:4321';

  @override
  Stream<List<int>> get bytes => _bytes.stream;

  @override
  void send(List<int> bytes) => sent.add(List.of(bytes));

  void push(Map<String, dynamic> packet) {
    _bytes.add(utf8.encode('${jsonEncode(packet)}\n'));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _bytes.close();
  }
}

class _FakeJournalStore extends JournalStore {
  _FakeJournalStore() : super(file: File('unused-p2p-sync-test.json'));

  final StreamController<List<JournalEntry>> _changes =
      StreamController<List<JournalEntry>>.broadcast();
  List<JournalEntry> entries = const [];

  @override
  Stream<List<JournalEntry>> watchAll() async* {
    yield entries;
    yield* _changes.stream;
  }

  @override
  Future<List<JournalEntry>> loadAll({bool includeDeleted = false}) async =>
      entries
          .where((entry) => includeDeleted || !entry.isDeleted)
          .toList(growable: false);

  @override
  Future<void> replaceAll(List<JournalEntry> next) async => emit(next);

  void emit(List<JournalEntry> next) {
    entries = List.unmodifiable(next);
    _changes.add(entries);
  }

  Future<void> close() => _changes.close();
}

JournalEntry _entry({
  required String transcript,
  required DateTime updatedAt,
  required String deviceId,
}) {
  return JournalEntry(
    id: 'shared-entry',
    createdAt: DateTime.utc(2026, 7, 29, 9),
    transcript: transcript,
    durationSeconds: 10,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncMetadata: JournalSyncMetadata(
      updatedAt: updatedAt,
      sourceDeviceId: deviceId,
    ),
  );
}

Map<String, dynamic> _decodePacket(List<int> bytes) {
  return Map<String, dynamic>.from(
    jsonDecode(utf8.decode(bytes).trim()) as Map,
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for mesh synchronization.');
}
