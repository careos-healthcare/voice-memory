import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_queue.dart';
import 'package:voicememory_mobile/features/capture_api_retry/capture_api_retry_queue.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

import 'support/scripted_sync_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one Wi-Fi transition drains capture and graph queues without loss',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'combined_recovery_e2e_',
      );
      final connectivity = ConnectivityHarness();
      final keyStore = InMemoryPrivateDataEncryptionKeyStore(
        seedKey: List<int>.generate(32, (index) => 31 - index),
      );
      final journal = await JournalStore.open(
        '${root.path}/journal.json',
        keyStore: keyStore,
      );
      final captureApi = _CaptureApi();
      var captureId = 0;
      final captureQueue = CaptureApiRetryQueue(
        manifestFile: File('${root.path}/capture.enc'),
        keyStore: keyStore,
        api: captureApi,
        attest: _Attest(captureApi),
        journalStore: journal,
        connectivityChanges: connectivity.stream,
        isOnline: connectivity.isOnline,
        idFactory: () => 'capture-${captureId++}',
      );
      final graphTransport = _GraphTransport();
      var graphId = 0;
      final graphQueue = EncryptedGraphSyncQueue(
        manifestFile: File('${root.path}/graph.enc'),
        keyStore: keyStore,
        transport: graphTransport,
        connectivityChanges: connectivity.stream,
        foregroundUnlocked: () async => true,
        isOnline: connectivity.isOnline,
        idFactory: () => 'graph-${graphId++}',
        delay: (_) async {},
      );
      addTearDown(() async {
        await captureQueue.dispose();
        await graphQueue.dispose();
        await connectivity.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });

      connectivity.emitOffline();
      for (final id in <String>['capture-a', 'capture-b']) {
        await journal.save(
          JournalEntry(
            id: id,
            createdAt: DateTime.utc(2026, 7, 26),
            transcript: 'private $id',
            durationSeconds: 1,
            reflection: _emptyReflection,
            syncStatus: SyncStatus.localOnly,
          ),
        );
        await captureQueue.enqueueAnalyze(
          entryId: id,
          transcript: 'private $id',
          idempotencyKey: 'key-$id',
        );
      }
      for (final path in <String>[
        'ArchiveMe_Sync/graph-a.enc',
        'ArchiveMe_Sync/graph-b.enc',
      ]) {
        await graphQueue.upload(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: path,
          encryptedEnvelope: _envelope,
        );
      }
      expect(await captureQueue.jobs, hasLength(2));
      expect(await graphQueue.items, hasLength(2));

      connectivity.emitWifi();
      await pumpUntil(
        () async =>
            (await captureQueue.jobs).isEmpty &&
            (await graphQueue.items).isEmpty,
      );

      expect(captureApi.keys.toSet(), <String>{
        'key-capture-a',
        'key-capture-b',
      });
      expect(captureApi.keys, hasLength(2));
      expect(graphTransport.paths.toSet(), <String>{
        'ArchiveMe_Sync/graph-a.enc',
        'ArchiveMe_Sync/graph-b.enc',
      });
      expect(graphTransport.paths, hasLength(2));
      expect((await journal.loadAll()).map((entry) => entry.id).toSet(), {
        'capture-a',
        'capture-b',
      });
    },
  );
}

const _emptyReflection = Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: <String>[],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

const _envelope =
    '{"version":1,"algorithm":"AES-256-GCM",'
    '"kdf":"PBKDF2-HMAC-SHA256","mode":"portable",'
    '"salt":"AAAAAAAAAAAAAAAAAAAAAA==","iterations":210000,'
    '"nonce":"AAAAAAAAAAAAAAAA","ciphertext":"AQ==",'
    '"mac":"AAAAAAAAAAAAAAAAAAAAAA=="}';

final class _CaptureApi extends VoiceCaptureApiClient {
  _CaptureApi() : super(ApiTransport(baseUrl: 'https://example.test'));

  final List<String> keys = <String>[];

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    keys.add(idempotencyKey!);
    return const Reflection(
      mood: 'steady',
      emotionalIntensity: 1,
      recurringThemes: <String>[],
      exactLanguagePattern: '',
      concreteObservation: 'recovered',
      repeatedSignal: '',
    );
  }
}

final class _GraphTransport implements EncryptedGraphSyncTransport {
  final List<String> paths = <String>[];

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) async => _envelope;

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    paths.add(path);
  }
}

final class _Attest extends CaptureAttestService {
  _Attest(VoiceCaptureApiClient api)
    : super(api: api, deviceIds: _DeviceIds(), tokenCache: CaptureTokenCache());

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'token';
}

final class _DeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device';
}
