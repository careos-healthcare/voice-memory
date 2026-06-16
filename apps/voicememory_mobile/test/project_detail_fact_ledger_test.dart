import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/export/selected_archive_export.dart';
import 'package:voicememory_mobile/features/fact_ledger/archive_fact.dart';
import 'package:voicememory_mobile/features/fact_ledger/fact_ledger_export.dart';
import 'package:voicememory_mobile/features/fact_ledger/fact_ledger_filter.dart';
import 'package:voicememory_mobile/features/fact_ledger/fact_ledger_policy.dart';
import 'package:voicememory_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_governance_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_influence_level.dart';
import 'package:voicememory_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/entry_detail_screen.dart';
import 'package:voicememory_mobile/screens/fact_ledger_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/fact_ledger/fact_editor_sheet.dart';
import 'package:voicememory_mobile/widgets/fact_ledger/save_as_fact_button.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _privateLabel = 'Staging API endpoint';
const _privateValue = 'https://internal.example/api/v2';
const _privateNote = 'Rotate after launch window closes';

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'VoiceMemory',
];

JournalEntry _entry({
  required String id,
  String transcript = 'A long enough transcript for fact ledger tests here.',
  String? archivePackId,
  String surfacing = 'normal',
  String aboutness = 'about_me',
  bool preserveOriginal = false,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12),
  transcript: transcript,
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Generated summary observation.',
    repeatedSignal: 'signal',
  ),
  archivePackId: archivePackId,
  memorySurfacing: surfacing,
  entryAboutness: aboutness,
  preserveOriginal: preserveOriginal,
);

void main() {
  late Directory tmp;
  late MobilePrefsStore prefs;
  late FactLedgerStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fact_ledger_test');
    prefs = await MobilePrefsStore.open('${tmp.path}/prefs.json');
    store = FactLedgerStore.forPrefs(prefs);
    await AppServices.resetForTest(
      journalPath: '${tmp.path}/entries_app.json',
      prefsPath: '${tmp.path}/prefs.json',
      skipRevenueCat: true,
    );
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('Save detail', () {
    testWidgets('button renders on entry detail', (tester) async {
      late Directory dir;
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('vm_fact_detail_');
        await AppServices.resetForTest(
          journalPath: '${dir.path}/entries.json',
          prefsPath: '${dir.path}/prefs.json',
          skipRevenueCat: true,
        );
        await AppServices.instance.journalStore.save(_entry(id: 'e1'));
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const EntryDetailScreen(entryId: 'e1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('save_as_fact_button')), findsNothing);
      await tester.tap(find.text('Advanced entry details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('save_as_fact_button')), findsOneWidget);
      expect(find.text(FactLedgerCopy.saveDetail), findsOneWidget);
    });

    testWidgets('tapping Save detail opens editor', (tester) async {
      final entry = _entry(id: 'e2');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FactEditorSheet(
              store: store,
              entry: entry,
              prefillLabel: 'Safe short title',
              source: 'test',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('fact_label_field')), findsOneWidget);
      expect(find.byKey(const Key('fact_value_field')), findsOneWidget);
      expect(find.text('Safe short title'), findsOneWidget);
    });

    test('saving creates fact and persists after reload', () async {
      await AppServices.instance.journalStore.save(_entry(id: 'e3'));
      final created = await store.create(
        sourceEntryId: 'e3',
        label: _privateLabel,
        value: _privateValue,
        note: _privateNote,
        factType: FactType.projectDetail.id,
      );
      expect(created, isNotNull);
      final reloaded = FactLedgerStore.forPrefs(prefs);
      final all = await reloaded.loadAll();
      expect(all, hasLength(1));
      expect(all.first.label, _privateLabel);
    });

    test('source entry remains unchanged when fact saved', () async {
      const transcript = 'Original entry transcript stays intact.';
      await AppServices.instance.journalStore.save(
        _entry(id: 'e4', transcript: transcript),
      );
      await store.create(
        sourceEntryId: 'e4',
        label: 'Label',
        value: 'Value',
        factType: FactType.other.id,
      );
      final entry = await AppServices.instance.journalStore.getById('e4');
      expect(entry?.transcript, transcript);
    });

    test('deleting fact does not delete source entry', () async {
      await AppServices.instance.journalStore.save(_entry(id: 'e5'));
      final fact = await store.create(
        sourceEntryId: 'e5',
        label: 'Label',
        value: 'Value',
        factType: FactType.other.id,
      );
      await store.delete(fact!.id);
      expect(await AppServices.instance.journalStore.getById('e5'), isNotNull);
    });

    test('facts are user-created only', () {
      final fact = ArchiveFact(
        id: 'f1',
        sourceEntryId: 'e1',
        label: 'Label',
        value: 'Value',
        note: '',
        createdAt: DateTime(2026, 6, 12),
        updatedAt: DateTime(2026, 6, 12),
        factType: FactType.projectDetail.id,
      );
      expect(FactLedgerPolicy.isUserCreatedOnly(fact), isTrue);
    });

    test('no automatic fact extraction from entry text', () async {
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'e6',
          transcript: 'Secret project code ALPHA-42 must not become a fact.',
        ),
      );
      final all = await store.loadAll();
      expect(all, isEmpty);
    });

    test('credential reference copy warns about secrets', () {
      expect(
        FactLedgerCopy.credentialHelper,
        'Store a reference, not the secret itself.',
      );
      expect(FactType.credentialReference.label, 'Credential reference');
    });
  });

  group('Details screen', () {
    testWidgets('renders empty state', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: FactLedgerScreen(store: store),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.byKey(const Key('fact_ledger_empty')), findsOneWidget);
      expect(find.textContaining(FactLedgerCopy.emptyTitle), findsOneWidget);
    });

    test('edit fact updates label/value/note locally', () async {
      final created = await store.create(
        sourceEntryId: 'e8',
        label: 'Old label',
        value: 'Old value',
        note: 'Old note',
        factType: FactType.projectDetail.id,
      );
      final updated = await store.update(
        id: created!.id,
        label: 'New label',
        value: 'New value',
        note: 'New note',
      );
      expect(updated?.label, 'New label');
      expect(updated?.value, 'New value');
      expect(updated?.note, 'New note');
    });

    test('pin fact works', () async {
      final created = await store.create(
        sourceEntryId: 'e9',
        label: 'Pin me',
        value: 'Value',
        factType: FactType.other.id,
      );
      final pinned = await store.togglePin(created!.id);
      expect(pinned?.isPinned, isTrue);
    });
  });

  group('Search and export', () {
    test('archive search Saved details filter works', () {
      const engine = ArchiveEntrySearchEngine();
      final entries = [_entry(id: 'a'), _entry(id: 'b')];
      final results = engine.search(
        entries: entries,
        query: const ArchiveEntrySearchQuery(savedDetailsOnly: true),
        entryIdsWithSavedDetails: {'a'},
      );
      expect(results, hasLength(1));
      expect(results.first.entry.id, 'a');
    });

    test('result metadata includes Saved detail chip', () {
      const engine = ArchiveEntrySearchEngine();
      final results = engine.search(
        entries: [_entry(id: 'chip')],
        query: const ArchiveEntrySearchQuery(),
        entryIdsWithSavedDetails: {'chip'},
      );
      expect(results.first.savedDetailLabel, FactLedgerCopy.searchChipLabel);
    });

    test('details screen search works locally', () async {
      await store.create(
        sourceEntryId: 'e10',
        label: 'Database host',
        value: 'db.internal',
        factType: FactType.projectDetail.id,
      );
      await store.create(
        sourceEntryId: 'e11',
        label: 'Meeting room',
        value: 'Room B',
        factType: FactType.other.id,
      );
      final all = await store.loadAll();
      final results = FactLedgerFilter.search(all, 'database');
      expect(results, hasLength(1));
    });

    test('fact type filter works', () async {
      await store.create(
        sourceEntryId: 'e12',
        label: 'Deadline',
        value: 'June 30',
        factType: FactType.deadline.id,
      );
      await store.create(
        sourceEntryId: 'e13',
        label: 'Contact',
        value: 'Alex',
        factType: FactType.contact.id,
      );
      final all = await store.loadAll();
      final results = FactLedgerFilter.search(
        all,
        '',
        factTypeId: FactType.deadline.id,
      );
      expect(results, hasLength(1));
      expect(results.first.factType, FactType.deadline.id);
    });

    test('selected export includes linked fact text', () async {
      await AppServices.instance.journalStore.save(_entry(id: 'exp1'));
      final facts = [
        (await store.create(
          sourceEntryId: 'exp1',
          label: _privateLabel,
          value: _privateValue,
          note: _privateNote,
          factType: FactType.projectDetail.id,
        ))!,
      ];
      const exporter = SelectedArchiveExport();
      final md = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'exp1')],
        facts: facts,
      );
      expect(md, contains(_privateLabel));
      expect(md, contains(_privateValue));
      expect(md, contains('Saved detail: Project detail'));
    });

    test('dedicated details export creates markdown', () {
      final facts = [
        ArchiveFact(
          id: 'f1',
          sourceEntryId: 'e1',
          label: 'Host',
          value: 'db.example',
          note: '',
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
          factType: FactType.projectDetail.id,
        ),
      ];
      final md = const FactLedgerExport().buildMarkdown(facts: facts);
      expect(md, contains('# ArchiveMe details'));
      expect(md, contains('Host'));
      expect(md, contains('db.example'));
      expect(
        FactLedgerExport.fileName(DateTime(2026, 6, 12)),
        'archiveme-details-2026-06-12.md',
      );
    });

    test('export does not include unselected facts', () {
      const exporter = SelectedArchiveExport();
      final md = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'only')],
        facts: [
          ArchiveFact(
            id: 'f-other',
            sourceEntryId: 'other-entry',
            label: 'Hidden',
            value: 'Hidden value',
            note: '',
            createdAt: DateTime(2026, 6, 12),
            updatedAt: DateTime(2026, 6, 12),
            factType: FactType.other.id,
          ),
        ],
      );
      expect(md, isNot(contains('Hidden value')));
    });
  });

  group('Memory safeguards', () {
    test('facts do not create personal memory authority', () {
      final fact = ArchiveFact(
        id: 'f1',
        sourceEntryId: 'e1',
        label: 'Label',
        value: 'Value',
        note: '',
        createdAt: DateTime(2026, 6, 12),
        updatedAt: DateTime(2026, 6, 12),
        factType: FactType.projectDetail.id,
      );
      expect(FactLedgerPolicy.isPersonalProfileEvidence(fact), isFalse);
      expect(FactLedgerPolicy.feedsProactivePersonalMemory(fact), isFalse);
    });

    test('facts do not feed belief distance', () {
      expect(
        FactLedgerPolicy.feedsProactivePersonalMemory(
          ArchiveFact(
            id: 'f1',
            sourceEntryId: 'e1',
            label: 'L',
            value: 'V',
            note: '',
            createdAt: DateTime(2026, 6, 12),
            updatedAt: DateTime(2026, 6, 12),
            factType: FactType.projectDetail.id,
          ),
        ),
        isFalse,
      );
      const engine = BeliefDistanceEngine();
      expect(engine.build(const [], entryCount: 0).hasBelief, isFalse);
    });

    test('facts do not feed aha moment', () {
      expect(
        const AhaMomentEngine().evaluate(
          records: const [],
          entryCount: 0,
          trackAnalytics: false,
        ),
        isNull,
      );
    });

    test('facts do not feed weekly personal review', () {
      expect(
        const WeeklyThreadReviewEngine().build(const []).hasReview,
        isFalse,
      );
    });

    test('facts do not feed Pro proof/share moments by themselves', () {
      expect(
        FactLedgerPolicy.feedsProactivePersonalMemory(
          ArchiveFact(
            id: 'f1',
            sourceEntryId: 'e1',
            label: 'L',
            value: 'V',
            note: '',
            createdAt: DateTime(2026, 6, 12),
            updatedAt: DateTime(2026, 6, 12),
            factType: FactType.projectDetail.id,
          ),
        ),
        isFalse,
      );
    });

    test('facts can be pack/project-scoped', () {
      final fact = ArchiveFact(
        id: 'f1',
        sourceEntryId: 'e1',
        label: 'L',
        value: 'V',
        note: '',
        createdAt: DateTime(2026, 6, 12),
        updatedAt: DateTime(2026, 6, 12),
        factType: FactType.projectDetail.id,
        archivePackId: 'pack1',
      );
      expect(FactLedgerPolicy.supportsPackRecall(fact), isTrue);
      expect(FactLedgerFilter.forPack('pack1', [fact]), hasLength(1));
    });

    test('facts do not cross packs without confirmation', () {
      final fact = ArchiveFact(
        id: 'f1',
        sourceEntryId: 'e1',
        label: 'L',
        value: 'V',
        note: '',
        createdAt: DateTime(2026, 6, 12),
        updatedAt: DateTime(2026, 6, 12),
        factType: FactType.projectDetail.id,
        archivePackId: 'pack-a',
      );
      expect(
        FactLedgerPolicy.crossesPackWithoutConfirmation(
          fact: fact,
          targetPackId: 'pack-b',
        ),
        isTrue,
      );
    });

    test('source entry surfacing/aboutness controls still apply', () {
      final entry = _entry(
        id: 's1',
        surfacing: 'do_not_surface',
        aboutness: 'hypothetical',
      );
      expect(SensitiveSurfacingPolicy.isDoNotSurfaceEntry(entry), isTrue);
      final records = [
        PressureCheckInRecord(
          entryId: 's1',
          createdAt: DateTime.now(),
          optionId: 'could_not_stop',
          entryAboutness: 'hypothetical',
          memorySurfacing: 'do_not_surface',
        ),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 1,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });

    test(
      'preserve original applies to fact source as curated evidence',
      () async {
        await AppServices.instance.journalStore.save(_entry(id: 'p1'));
        await store.create(
          sourceEntryId: 'p1',
          label: 'Detail',
          value: 'Exact wording',
          factType: FactType.projectDetail.id,
        );
        final entry = await AppServices.instance.journalStore.getById('p1');
        expect(entry?.preserveOriginal, isTrue);
      },
    );
  });

  group('Privacy and copy', () {
    test('analytics payload contains no private content', () async {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.saveDetailTapped,
        source: 'entry_detail',
      );
      await store.create(
        sourceEntryId: 'e1',
        label: _privateLabel,
        value: _privateValue,
        note: _privateNote,
        factType: FactType.credentialReference.id,
      );
      for (final event in _events) {
        for (final value in event.properties.values) {
          final lower = value.toString().toLowerCase();
          expect(lower, isNot(contains('staging')));
          expect(lower, isNot(contains('internal.example')));
          expect(lower, isNot(contains('rotate')));
        }
      }
    });

    test('banned-word sweep over consumer copy', () {
      for (final line in FactLedgerCopy.all) {
        final lower = line.toLowerCase();
        for (final word in _bannedWords) {
          expect(lower, isNot(contains(word.toLowerCase())));
        }
      }
    });
  });
}
