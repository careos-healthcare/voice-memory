import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:archiveme_mobile/core/hardware/hardware_state_provider.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_tagging_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/search/ui/semantic_search_view.dart';
import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:archiveme_mobile/features/sync/cloud_relay_service.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud relay encrypts while the secondary device is offline', () async {
    PremiumAccess.apply(PremiumEntitlement.active);
    addTearDown(() => PremiumAccess.apply(PremiumEntitlement.free));
    final crypto = SyncCrypto(List<int>.filled(32, 9));
    final bucket = MemoryCloudRelayBucket();
    final relay = CloudRelayService(crypto: crypto, bucket: bucket);

    expect(
      CloudRelayService.secondaryDeviceOnline(peerObserved: true),
      isFalse,
    );

    final envelope = await relay.relayIfSecondaryOffline(
      peerObserved: true,
      recordingId: 'rec-1',
      audioBytes: const [1, 2, 3, 4],
      transcript: 'rent is due tomorrow',
    );
    expect(envelope, isNotNull);
    expect(envelope!.payload.ciphertext.contains('rent'), isFalse);

    configureSqliteTestFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final inbox = CloudRelayInbox(db);
    final pulled = await CloudRelaySyncWorker(relay, inbox: inbox).pollOnce();
    expect(pulled, hasLength(1));
    expect(pulled.single.transcript, 'rent is due tomorrow');
    expect(pulled.single.audioBytes, const [1, 2, 3, 4]);
    expect(await bucket.list(), isEmpty);
    final stored = await inbox.read('rec-1');
    expect(stored!.transcript, 'rent is due tomorrow');
    expect(stored.audioBytes, const [1, 2, 3, 4]);
  });

  test(
    'paragraph search returns the closest chunk and its timestamp',
    () async {
      configureSqliteTestFfi();
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final service = VectorSearchService(
        store: SqliteTranscriptChunkStore(db),
        embedder: (text) async => hashTranscriptEmbedding(text),
      );
      await service.indexTranscript(
        entryId: 'entry-1',
        transcript: 'rent and bills\n\ntea with mum',
        durationSeconds: 120,
      );

      final hits = await service.search('rent');
      expect(hits, isNotEmpty);
      expect(hits.first.text, 'rent and bills');
      expect(hits.first.startSeconds, 0);
      expect(hits.first.timestampLabel, '00:00');
      expect(hits.last.startSeconds, 60);
      expect(hits.last.timestampLabel, '01:00');
    },
  );

  testWidgets('semantic search jumps to the matched timestamp', (tester) async {
    final service = VectorSearchService(
      store: MemoryTranscriptChunkStore(),
      embedder: (text) async => hashTranscriptEmbedding(text),
    );
    await service.indexTranscript(
      entryId: 'entry-1',
      transcript: 'rent and bills\n\ntea with mum',
      durationSeconds: 120,
    );
    SemanticSearchHit? jumped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          semanticSearchServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SemanticSearchView(onJump: (hit) => jumped = hit),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('semantic_search_field')),
      'rent',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Jump to 00:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('semantic_jump_entry-1_0')));
    await tester.pump();
    expect(jumped?.startSeconds, 0);
    expect(jumped?.text, 'rent and bills');
  });

  test('gemma tags save 3 to 5 labels and a folder', () async {
    const payload =
        '{"tags":["rent","bills","home","extra","more","dropped"],"folder":"Money"}';
    final parsed = parseContextTagJson(payload);
    expect(parsed!.tags, ['rent', 'bills', 'home', 'extra', 'more']);

    final service = GemmaTaggingService(
      completer: ({required systemPrompt, required userPrompt}) async =>
          payload,
    );
    final result = await service.tagTranscript('The rent and bills are due.');
    expect(result!.folder, 'Money');

    configureSqliteTestFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final store = ContextTagStore(db);
    await store.save('entry-1', result);
    final saved = await store.read('entry-1');
    expect(saved!.tags, result.tags);
    expect(saved.folder, 'Money');

    final scheduler = HeavyWorkScheduler();
    final deferred = GemmaTaggingService(
      completer: ({required systemPrompt, required userPrompt}) async =>
          payload,
      snapshot: const HardwareSnapshot(
        batteryPercent: 15,
        isCharging: false,
        thermalStatus: DeviceThermalStatus.serious,
      ),
      scheduler: scheduler,
    );
    expect(await deferred.tagTranscript('The rent and bills are due.'), isNull);

    final seen = <String>[];
    TranscriptionCompletionHooks.afterSuccess =
        (transcript, {String? entryId}) async {
          seen.add(transcript);
          if (entryId != null) seen.add(entryId);
        };
    addTearDown(() => TranscriptionCompletionHooks.afterSuccess = null);
    dispatchTranscriptReady('The rent and bills are due.');
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['The rent and bills are due.']);
  });
}
