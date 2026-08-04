import 'dart:typed_data';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:thermal/thermal.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/services/p2p_mesh/anchor_compute_channel.dart';
import 'package:voicememory_mobile/services/p2p_mesh/offload_policy_engine.dart';
import 'package:voicememory_mobile/services/p2p_mesh/task_router.dart';

void main() {
  group('OffloadPolicyEngine', () {
    test('strictly halts at iOS serious or Android SEVERE', () async {
      final engine = OffloadPolicyEngine.forTesting();
      engine
        ..updateBattery(level: 100, state: BatteryState.charging)
        ..updateConnectivity(const [ConnectivityResult.wifi])
        ..updateAnchorPing(const Duration(milliseconds: 20), connected: true)
        ..updateThermalStatus(ThermalStatus.severe);

      expect(engine.current.thermal, OffloadThermalState.serious);
      expect(engine.current.policy, OffloadPolicyState.haltCompute);
      await engine.dispose();
    });

    test('forces healthy Anchor offload under thermal pressure', () async {
      final engine = OffloadPolicyEngine.forTesting();
      engine
        ..updateBattery(level: 60, state: BatteryState.discharging)
        ..updateConnectivity(const [ConnectivityResult.wifi])
        ..updateAnchorPing(const Duration(milliseconds: 80), connected: true)
        ..updateThermalStatus(ThermalStatus.light);

      expect(engine.current.policy, OffloadPolicyState.forceOffload);
      await engine.dispose();
    });
  });

  group('TaskRouter', () {
    late Database database;
    late EncryptedComputeBacklog backlog;

    setUp(() {
      database = sqlite3.openInMemory();
      backlog = EncryptedComputeBacklog(
        database: database,
        codec: EncryptedSqliteTextCodec(
          () => Uint8List.fromList(List<int>.generate(32, (i) => i)),
        ),
      );
    });

    tearDown(() {
      database.close();
    });

    test('persists halted work encrypted without invoking compute', () async {
      final engine = OffloadPolicyEngine.forTesting()
        ..updateThermalStatus(ThermalStatus.severe);
      var localInvoked = false;
      var remoteInvoked = false;
      final router = TaskRouter(
        policy: engine,
        backlog: backlog,
        delegate:
            ({
              required AnchorComputeJobKind kind,
              required Map<String, dynamic> payload,
              Duration timeout = const Duration(seconds: 45),
            }) async {
              remoteInvoked = true;
              return const {};
            },
      );

      final result = await router.submit<String>(
        kind: RoutedComputeKind.llama,
        payload: const {'text': 'private council prompt'},
        runLocal: () async {
          localInvoked = true;
          return 'local';
        },
        decodeRemote: (_) => 'remote',
      );

      expect(result.disposition, TaskRouteDisposition.deferred);
      expect(localInvoked, isFalse);
      expect(remoteInvoked, isFalse);
      expect(backlog.length, 1);
      expect(
        backlog.readAll().single.payload['text'],
        'private council prompt',
      );
      final encrypted =
          database
                  .select(
                    'SELECT encrypted_payload FROM sovereign_compute_backlog',
                  )
                  .single['encrypted_payload']
              as String;
      expect(encrypted, isNot(contains('private council prompt')));
      await engine.dispose();
    });

    test('serializes force-offload jobs through the Anchor delegate', () async {
      final engine = OffloadPolicyEngine.forTesting();
      engine
        ..updateBattery(level: 20, state: BatteryState.discharging)
        ..updateConnectivity(const [ConnectivityResult.wifi])
        ..updateAnchorPing(const Duration(milliseconds: 40), connected: true)
        ..updateThermalStatus(ThermalStatus.none);
      final router = TaskRouter(
        policy: engine,
        backlog: backlog,
        delegate:
            ({
              required AnchorComputeJobKind kind,
              required Map<String, dynamic> payload,
              Duration timeout = const Duration(seconds: 45),
            }) async {
              expect(kind, AnchorComputeJobKind.batchEmbeddings);
              expect(payload['texts'], const ['memory']);
              return const {
                'vectors': [
                  [1.0, 2.0],
                ],
              };
            },
      );

      final result = await router.submit<List<dynamic>>(
        kind: RoutedComputeKind.embedding,
        payload: const {
          'texts': ['memory'],
        },
        runLocal: () async => const ['local'],
        decodeRemote: (value) => value['vectors'] as List<dynamic>,
      );

      expect(result.disposition, TaskRouteDisposition.offloaded);
      expect(result.value, const [
        [1.0, 2.0],
      ]);
      expect(backlog.length, 0);
      await engine.dispose();
    });
  });
}
