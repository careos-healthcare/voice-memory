import 'package:archiveme_mobile/features/ai_coaching/ask_the_coach_panel.dart';
import 'package:archiveme_mobile/features/ai_coaching/ask_the_coach_service.dart';
import 'package:archiveme_mobile/features/ai_coaching/coach_action_plan.dart';
import 'package:archiveme_mobile/features/ai_coaching/coach_action_store.dart';
import 'package:archiveme_mobile/features/ai_coaching/recording_coach_hook.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/search/vec_search_service.dart';
import 'package:archiveme_mobile/features/transcript/ui/transcript_detail_view.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('action items keep a timeline estimate', () {
    final items = CoachActionPlan.fromTranscript(
      'I need to call Ada tomorrow. The weather was fine.',
      durationSeconds: 40,
    );
    expect(items, hasLength(1));
    expect(items.single.text, contains('call Ada'));
    expect(items.single.timelineLabel, 'Tomorrow');
    expect(items.single.estimateMinutes, 24 * 60);
  });

  test('stopping a recording stores action items in sqlite', () async {
    configureSqliteTestFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(() async {
      RecordingCoachHook.store = null;
      await db.close();
    });
    RecordingCoachHook.bind(db);
    await RecordingCoachHook.onTranscriptReady(
      'Remember to buy milk in 20 minutes.',
      entryId: 'entry-1',
    );
    final stored = await CoachActionStore(db).read('entry-1');
    expect(stored.single.timelineLabel, 'On the clock in this note');
    expect(stored.single.estimateMinutes, 20);
  });

  test('dispatchTranscriptReady starts the coach hook', () async {
    configureSqliteTestFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(() async {
      RecordingCoachHook.store = null;
      await db.close();
    });
    RecordingCoachHook.bind(db);
    dispatchTranscriptReady(
      'Remember to buy milk in 20 minutes.',
      entryId: 'entry-2',
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final stored = await CoachActionStore(db).read('entry-2');
    expect(stored.single.estimateMinutes, 20);
  });

  test('coach answers from a local sqlite-vec hit', () async {
    configureSqliteTestFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final service = AskTheCoachService(
      database: db,
      embed: (_) => const [1, 0],
      readNote: (id) async => id == 'ada' ? 'Finished the run with Ada.' : null,
      vectors: VecSearchService(
        loadDistances: (db, query, limit) async {
          expect(query, isNotEmpty);
          return const [VecDistanceHit(entryId: 'ada', distance: 0.2)];
        },
      ),
    );

    final reply = await service.ask('Where was Ada?');
    expect(reply.answer, contains('Finished the run with Ada.'));
    expect(reply.citations.single.entryId, 'ada');

    final missed = await service.ask('');
    expect(missed.citations, isEmpty);
  });

  testWidgets('ask the coach shows the local reply', (tester) async {
    configureSqliteTestFfi();
    final service = await tester.runAsync(() async {
      final db = await openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      return AskTheCoachService(
        database: db,
        embed: (_) => const [1],
        readNote: (_) async => 'The rent is due.',
        vectors: VecSearchService(
          loadDistances: (_, _, _) async => const [
            VecDistanceHit(entryId: 'rent', distance: 0.1),
          ],
        ),
      );
    });
    expect(service, isNotNull);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(
            MonetizationRevenueCatService(seed: PremiumEntitlement.active),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: AskTheCoachPanel(service: service!)),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('ask_the_coach_input')),
      'rent',
    );
    await tester.tap(find.byKey(const Key('ask_the_coach_send')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('coach_reply')), findsOneWidget);
    expect(find.textContaining('The rent is due.'), findsOneWidget);
  });

  testWidgets('a phrase can be tagged and saved as a clip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TranscriptDetailView(
              entryId: 'entry-2',
              transcript: 'Call Ada tomorrow about the run.',
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('transcript_phrase_input')),
      'Call Ada',
    );
    await tester.enterText(
      find.byKey(const Key('transcript_tag_input')),
      'ada',
    );
    await tester.tap(find.byKey(const Key('transcript_save_clip')));
    await tester.pump();
    expect(find.text('Call Ada (ada)'), findsOneWidget);
  });
}
