import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_context.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/evidence_context_tag_card.dart';

import 'support/memory_pressure_stores.dart';
import 'support/test_storage_sandbox.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// Context-only tag record, exactly as [PressureCheckInStore.addContextTag]
/// creates it for an entry without a check-in.
PressureCheckInRecord _tagOnlyRecord({
  required String id,
  int daysAgo = 0,
  String contextId = 'work',
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: PressureCheckInRecord.contextOnlyOptionId,
    contextIds: [contextId],
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required ValueChanged<PressureContext> onSaveTag,
  required VoidCallback onSkip,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EvidenceContextTagCard(onSaveTag: onSaveTag, onSkip: onSkip),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {

  group('Evidence context tag card', () {
    testWidgets('renders one optional question with the short tag list', (
      tester,
    ) async {
      await _pumpCard(tester, onSaveTag: (_) {}, onSkip: () {});

      expect(
        find.byKey(const Key('evidence_context_tag_card')),
        findsOneWidget,
      );
      expect(find.text('Add context?'), findsOneWidget);
      expect(
        find.text('This helps ArchiveMe connect future evidence.'),
        findsOneWidget,
      );
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Save context'), findsOneWidget);
      // The fixed short list, nothing more.
      expect(EvidenceContextTagCard.tags.length, 8);
      for (final label in const [
        'Work',
        'Family',
        'Money',
        'Health',
        'Stopping',
        'Deadline',
        'People',
        'Energy',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('save stays disabled until a tag is chosen', (tester) async {
      PressureContext? saved;
      await _pumpCard(tester, onSaveTag: (t) => saved = t, onSkip: () {});

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('evidence_context_tag_save')),
      );
      expect(saveButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const Key('evidence_context_tag_save')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(saved, isNull);
    });

    testWidgets('selecting one tag stores it on save', (tester) async {
      PressureContext? saved;
      await _pumpCard(tester, onSaveTag: (t) => saved = t, onSkip: () {});

      await tester.tap(find.byKey(const Key('evidence_context_tag_money')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('evidence_context_tag_save')));
      await tester.pump();

      expect(saved, PressureContext.money);
    });

    testWidgets('only one tag can be selected at a time', (tester) async {
      await _pumpCard(tester, onSaveTag: (_) {}, onSkip: () {});

      await tester.tap(find.byKey(const Key('evidence_context_tag_work')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('evidence_context_tag_energy')));
      await tester.pump();

      var selectedCount = 0;
      for (final tag in EvidenceContextTagCard.tags) {
        final chip = tester.widget<ChoiceChip>(
          find.byKey(Key('evidence_context_tag_${tag.id}')),
        );
        if (chip.selected) selectedCount++;
        if (chip.selected) expect(tag, PressureContext.energy);
      }
      expect(selectedCount, 1);
    });

    testWidgets('skip works without storing anything', (tester) async {
      PressureContext? saved;
      var skipped = false;
      await _pumpCard(
        tester,
        onSaveTag: (t) => saved = t,
        onSkip: () => skipped = true,
      );

      await tester.tap(find.byKey(const Key('evidence_context_tag_skip')));
      await tester.pump();

      expect(skipped, isTrue);
      expect(saved, isNull);
    });

    test('no required or pressure language in the copy', () {
      final copy = [
        EvidenceContextTagCard.title,
        EvidenceContextTagCard.helperLine,
        EvidenceContextTagCard.skipLabel,
        EvidenceContextTagCard.saveLabel,
        ...EvidenceContextTagCard.tags.map((t) => t.label),
      ].join(' ');
      final lower = copy.toLowerCase();
      for (final banned in const [
        'must',
        'should',
        'task',
        'homework',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'required',
        'streak',
      ]) {
        expect(
          lower,
          isNot(contains(banned)),
          reason: 'tag copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });

  group('Context tag storage', () {
    late Directory tempDir;
    late PressureCheckInStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vm_context_tag_');
      final file = File('${tempDir.path}/prefs.json')..writeAsStringSync('{}');
      store = PressureCheckInStore.forPrefs(MobilePrefsStore(file: file));
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
      'tagging an entry without a check-in creates a context-only record',
      () async {
        await store.addContextTag(
          entryId: 'j1',
          contextId: 'family',
          now: _base,
        );

        final records = await store.loadAll();
        expect(records.length, 1);
        final record = records.single;
        expect(record.entryId, 'j1');
        expect(record.contextIds, ['family']);
        expect(record.optionId, PressureCheckInRecord.contextOnlyOptionId);
        // Marker option resolves to no real check-in option, and the record
        // holds no notes that any engine could quote.
        expect(record.option, isNull);
        expect(record.fear, isNull);
        expect(record.stopCostNote, isNull);
      },
    );

    test('tagging an entry with a check-in appends to its contexts', () async {
      await store.save(_record(id: 'p1', contextIds: const ['evening']));
      await store.addContextTag(entryId: 'p1', contextId: 'money');

      final record = (await store.loadAll()).single;
      expect(record.contextIds, ['evening', 'money']);
      // Existing fields are preserved.
      expect(record.optionId, 'could_not_stop');
      expect(record.transcript, 'pressure moment');
    });

    test('the same tag is never stored twice', () async {
      await store.addContextTag(entryId: 'j1', contextId: 'work', now: _base);
      await store.addContextTag(entryId: 'j1', contextId: 'work', now: _base);

      final record = (await store.loadAll()).single;
      expect(record.contextIds, ['work']);
    });
  });

  group('Tags feed future evidence safely', () {
    test('thread evidence can use the tag as context', () {
      const engine = ThreadReturnEvidenceEngine();
      final evidence = engine.build([
        _record(id: 'p1', daysAgo: 3, contextIds: const ['work']),
        _tagOnlyRecord(id: 'j1', daysAgo: 0, contextId: 'work'),
      ], now: _base);

      expect(evidence.hasEvidence, isTrue);
      expect(evidence.sourceTerms, contains('work'));
      expect(evidence.entryIds, containsAll(['p1', 'j1']));
    });

    test('tags alone do not create belief-distance phrases', () {
      const engine = BeliefDistanceEngine();
      final belief = engine.build([
        _tagOnlyRecord(id: 'j1', daysAgo: 4, contextId: 'stopping'),
        _tagOnlyRecord(id: 'j2', daysAgo: 2, contextId: 'stopping'),
        _tagOnlyRecord(id: 'j3', daysAgo: 0, contextId: 'stopping'),
      ]);

      expect(belief.hasBelief, isFalse);
      expect(belief.beliefLine, isEmpty);
      expect(belief.evidenceSnippets, isEmpty);
    });

    test('every suggested tag is a real context the engines understand', () {
      for (final tag in EvidenceContextTagCard.tags) {
        expect(PressureContext.fromId(tag.id), tag);
      }
    });
  });

  group('Record screen integration', () {

  late TestStorageSandbox sandbox;


    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() => sandbox.dispose());

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('context tag prompt does not appear before save', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: MemoryPressureCheckInStore(),
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('evidence_context_tag_card')), findsNothing);
      expect(find.text('Add context?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
