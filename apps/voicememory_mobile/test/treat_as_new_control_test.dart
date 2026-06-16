import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/memory/treat_as_new.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/memory/treat_as_new_control.dart';

import 'support/memory_pressure_stores.dart';

const _threadEngine = ThreadReturnEvidenceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();
const _beliefEngine = BeliefDistanceEngine();

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

List<_Event> _eventsNamed(String name) =>
    _events.where((e) => e.name == name).toList();

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 10, 9),
  transcript:
      transcript ?? 'A long enough transcript to count as a saved reflection.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: 'signal',
  ),
);

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String? fear,
  bool treatAsNew = false,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: contexts,
  fear: fear,
  treatAsNew: treatAsNew,
);

/// Engine-grade evidence: a work thread with repeated language across days.
List<PressureCheckInRecord> _evidenceRecords({bool treatAsNew = false}) => [
  _rec(
    id: 'e1',
    daysAgo: 6,
    fear: 'I keep circling the same work decision',
    treatAsNew: treatAsNew,
  ),
  _rec(
    id: 'e2',
    daysAgo: 3,
    fear: 'The same work decision came back today',
    treatAsNew: treatAsNew,
  ),
  _rec(
    id: 'e3',
    daysAgo: 0,
    fear: 'Circling the same work decision tonight',
    treatAsNew: treatAsNew,
  ),
];

void main() {
  setUp(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
    TreatAsNew.resetSessionForTest();
  });

  tearDown(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    TreatAsNew.resetSessionForTest();
  });

  group('Record screen visibility', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_treat_as_new_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpRecordScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('control appears before the first save and is off', (
      tester,
    ) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('treat_as_new_control')), findsOneWidget);
      expect(find.text(TreatAsNew.controlLabel), findsOneWidget);
      expect(find.text(TreatAsNew.helper), findsOneWidget);
      expect(TreatAsNew.selectedForNextSave, isFalse);
      expect(
        _eventsNamed(ActivationFunnelAnalytics.treatAsNewSeen),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('control appears for later saves too', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry('e1'));
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('treat_as_new_control')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Toggle behavior', () {
    testWidgets('default is off and tapping toggles the selected state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TreatAsNewControl())),
      );
      expect(TreatAsNew.selectedForNextSave, isFalse);
      expect(
        find.byKey(const Key('treat_as_new_expanded_helper')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('treat_as_new_control')));
      await tester.pump();
      expect(TreatAsNew.selectedForNextSave, isTrue);
      expect(
        find.byKey(const Key('treat_as_new_expanded_helper')),
        findsOneWidget,
      );
      expect(find.text(TreatAsNew.expandedHelper), findsOneWidget);

      await tester.tap(find.byKey(const Key('treat_as_new_control')));
      await tester.pump();
      expect(TreatAsNew.selectedForNextSave, isFalse);
      expect(
        find.byKey(const Key('treat_as_new_expanded_helper')),
        findsNothing,
      );

      final selected = _eventsNamed(
        ActivationFunnelAnalytics.treatAsNewSelected,
      );
      expect(selected, hasLength(2));
      expect(selected.first.properties['enabled'], 'true');
      expect(selected.last.properties['enabled'], 'false');
    });
  });

  group('Save metadata', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_treat_save_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
    });

    test('selected save writes the safe metadata flag only', () async {
      final store = AppServices.instance.journalStore;
      TreatAsNew.selectedForNextSave = true;
      final original = _entry('fresh1', transcript: 'Exact words, untouched.');
      await store.save(original);

      final all = await store.loadAll();
      final saved = all.singleWhere((e) => e.id == 'fresh1');
      expect(saved.treatAsNew, isTrue);
      // Raw text and metadata are untouched — flag only.
      expect(saved.transcript, 'Exact words, untouched.');
      expect(saved.createdAt, original.createdAt);
      expect(
        File('${tempDir.path}/journal.json').readAsStringSync(),
        contains('"treatAsNew":true'),
      );

      // Per-entry: the selection is consumed by the save.
      expect(TreatAsNew.selectedForNextSave, isFalse);
      expect(TreatAsNew.lastSaveWasFresh, isTrue);

      final savedEvents = _eventsNamed(
        ActivationFunnelAnalytics.treatAsNewSaved,
      );
      expect(savedEvents, hasLength(1));
      expect(savedEvents.single.properties['enabled'], 'true');
      expect(savedEvents.single.properties['entry_count'], 1);
    });

    test('unselected save does not write the flag', () async {
      final store = AppServices.instance.journalStore;
      await store.save(_entry('plain1'));

      final all = await store.loadAll();
      expect(all.singleWhere((e) => e.id == 'plain1').treatAsNew, isFalse);
      expect(
        File('${tempDir.path}/journal.json').readAsStringSync(),
        isNot(contains('treatAsNew')),
      );
      expect(TreatAsNew.lastSaveWasFresh, isFalse);
      expect(_eventsNamed(ActivationFunnelAnalytics.treatAsNewSaved), isEmpty);
    });

    test('a later unselected save clears the fresh receipt state', () async {
      final store = AppServices.instance.journalStore;
      TreatAsNew.selectedForNextSave = true;
      await store.save(_entry('fresh2'));
      expect(TreatAsNew.lastSaveWasFresh, isTrue);

      await store.save(_entry('plain2'));
      expect(TreatAsNew.lastSaveWasFresh, isFalse);
    });

    testWidgets('post-save fresh-entry copy renders the exact lines', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FreshEntrySavedReceipt())),
      );
      expect(find.text(TreatAsNew.postSaveTitle), findsOneWidget);
      expect(find.text(TreatAsNew.postSaveBody), findsOneWidget);
    });
  });

  group('Engine exclusion', () {
    test('thread return evidence ignores treat-as-new entries', () {
      // All candidates flagged → no memory claim at all.
      expect(
        _threadEngine.build(_evidenceRecords(treatAsNew: true)).hasEvidence,
        isFalse,
      );

      // A flagged entry never extends an existing claim.
      final base = _evidenceRecords();
      final baseline = _threadEngine.build(base);
      final withFlagged = _threadEngine.build([
        ...base,
        _rec(
          id: 'flagged',
          daysAgo: 0,
          fear: 'The same work decision again, kept separate',
          treatAsNew: true,
        ),
      ]);
      expect(baseline.hasEvidence, isTrue);
      expect(withFlagged.hasEvidence, isTrue);
      expect(withFlagged.occurrenceCount, baseline.occurrenceCount);
      expect(withFlagged.entryIds, isNot(contains('flagged')));
    });

    test('weekly review makes no claims from treat-as-new entries alone', () {
      expect(
        _weeklyEngine.build(_evidenceRecords(treatAsNew: true)).hasReview,
        isFalse,
      );
    });

    test('belief distance makes no claim from treat-as-new entries alone', () {
      expect(
        _beliefEngine.build(_evidenceRecords(treatAsNew: true)).hasBelief,
        isFalse,
      );
    });

    test('existing non-fresh evidence still works normally', () {
      final records = _evidenceRecords();
      expect(_threadEngine.build(records).hasEvidence, isTrue);
      expect(_weeklyEngine.build(records).hasReview, isTrue);
      expect(_beliefEngine.build(records).hasBelief, isTrue);

      // Mixed archives keep their old evidence even when newer entries
      // are kept separate.
      final mixed = [
        ...records,
        _rec(id: 'm1', daysAgo: 0, fear: 'Separate thought', treatAsNew: true),
      ];
      expect(_threadEngine.build(mixed).hasEvidence, isTrue);
      expect(_weeklyEngine.build(mixed).hasReview, isTrue);
      expect(_beliefEngine.build(mixed).hasBelief, isTrue);
    });
  });

  group('Analytics privacy', () {
    testWidgets('payloads carry only entry_count and enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TreatAsNewControl(entryCount: 3)),
        ),
      );
      await tester.tap(find.byKey(const Key('treat_as_new_control')));
      await tester.pump();
      TreatAsNew.applyToNewEntry(
        _entry('a1', transcript: 'Private words about a work decision.'),
        entryCount: 4,
      );

      final relevant = _events
          .where(
            (e) => const {
              'treat_as_new_seen',
              'treat_as_new_selected',
              'treat_as_new_saved',
            }.contains(e.name),
          )
          .toList();
      expect(relevant, isNotEmpty);
      for (final event in relevant) {
        for (final entry in event.properties.entries) {
          expect(
            const {'entry_count', 'enabled'}.contains(entry.key),
            isTrue,
            reason: 'unexpected property ${entry.key} on ${event.name}',
          );
          final value = entry.value;
          if (value is String) {
            expect(value == 'true' || value == 'false', isTrue);
          } else {
            expect(value, isA<int>());
          }
          // Never any entry text or fragments of it.
          expect('$value'.contains('decision'), isFalse);
          expect('$value'.contains('Private'), isFalse);
        }
      }
    });
  });

  group('Copy guardrails', () {
    const allCopy = [
      TreatAsNew.controlLabel,
      TreatAsNew.helper,
      TreatAsNew.expandedHelper,
      TreatAsNew.postSaveTitle,
      TreatAsNew.postSaveBody,
    ];

    test('expected exact copy', () {
      expect(TreatAsNew.controlLabel, 'Treat this as new');
      expect(TreatAsNew.helper, 'Not everything needs to connect.');
      expect(
        TreatAsNew.expandedHelper,
        'ArchiveMe will save this entry without using it to suggest a '
        'connection right now.',
      );
      expect(TreatAsNew.postSaveTitle, 'Saved as a fresh entry.');
      expect(
        TreatAsNew.postSaveBody,
        'ArchiveMe will not force this into an old pattern.',
      );
    });

    test('no VoiceMemory in consumer copy', () {
      final flat = allCopy.join(' ').toLowerCase();
      expect(flat, isNot(contains('voicememory')));
      expect(flat, isNot(contains('voice memory')));
    });

    test('banned-word sweep', () {
      final flat = allCopy.join(' ').toLowerCase();
      for (final banned in const [
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
      ]) {
        expect(
          RegExp('\\b$banned\\b').hasMatch(flat),
          isFalse,
          reason: 'copy must not contain "$banned"',
        );
      }
    });
  });
}
