import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_engine.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack_scope_policy.dart';
import 'package:voicememory_mobile/features/archive_packs/cross_pack_confirmation.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/export/selected_archive_export.dart';
import 'package:voicememory_mobile/features/memory/entry_aboutness.dart';
import 'package:voicememory_mobile/features/memory/entry_memory_mode.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_governance_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_reliability_check.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/features/trust/archive_trust_receipt.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/memory/entry_aboutness_editor.dart';
import 'package:voicememory_mobile/widgets/memory/entry_options_section.dart';

import 'support/expand_advanced_save_options.dart';
import 'package:voicememory_mobile/widgets/memory/not_about_me_receipt.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

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
  String aboutness = 'about_me',
  String? archivePackId,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12),
  transcript: 'A long enough transcript for archive search and export.',
  durationSeconds: 12,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Observation text.',
    repeatedSignal: 'signal',
  ),
  entryAboutness: aboutness,
  archivePackId: archivePackId,
);

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  String aboutness = 'about_me',
  String? fear,
  String? archiveThreadId,
  String? archivePackId,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: const ['work'],
  fear: fear,
  archiveThreadId: archiveThreadId,
  archivePackId: archivePackId,
  entryAboutness: aboutness,
);

List<PressureCheckInRecord> _personalEvidence() => [
  _rec(id: 'e1', daysAgo: 6, fear: 'I keep circling the same work decision'),
  _rec(id: 'e2', daysAgo: 3, fear: 'The same work decision came back today'),
  _rec(id: 'e3', daysAgo: 0, fear: 'Circling the same work decision tonight'),
];

void _reset() {
  MemoryScopePolicy.resetForTest();
  MemoryGovernancePolicy.resetForTest();
  EntryAboutnessSession.resetSessionForTest();
  EntryMemoryModeSession.resetSessionForTest();
  CrossPackConfirmation.resetForTest();
  ArchivePackScopePolicy.resetForTest();
  ArchiveTrustReceipt.resetForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

void main() {
  setUp(_reset);

  group('Entry aboutness picker', () {
    testWidgets('renders under entry options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: EntryOptionsSection(entryCount: 2),
            ),
          ),
        ),
      );
      await tester.pump();
      await expandAdvancedSaveOptions(tester);
      expect(find.byKey(const Key('entry_aboutness_picker')), findsOneWidget);
      expect(find.text('What kind of entry is this?'), findsOneWidget);
    });

    test('default is About me', () {
      expect(EntryAboutnessSession.selected, EntryAboutness.aboutMe);
    });
  });

  group('Save persistence', () {
    Future<JournalEntry> saveWith(EntryAboutness aboutness) async {
      EntryAboutnessSession.select(aboutness, entryCount: 2);
      final entry = _entry(id: 'save1');
      return EntryAboutnessSession.applyToNewEntry(entry, entryCount: 2);
    }

    test('selecting Hypothetical persists on save', () async {
      final saved = await saveWith(EntryAboutness.hypothetical);
      expect(saved.entryAboutness, 'hypothetical');
    });

    test('selecting Not about me persists on save', () async {
      final saved = await saveWith(EntryAboutness.notAboutMe);
      expect(saved.entryAboutness, 'not_about_me');
    });

    test('selecting Project material persists on save', () async {
      final saved = await saveWith(EntryAboutness.projectMaterial);
      expect(saved.entryAboutness, 'project_material');
    });

    test('selecting Research note persists on save', () async {
      final saved = await saveWith(EntryAboutness.researchNote);
      expect(saved.entryAboutness, 'research_note');
    });
  });

  group('Personal memory exclusion', () {
    test('non-personal entries do not feed belief distance', () {
      final records = [
        _rec(
          id: 'b0',
          daysAgo: 4,
          aboutness: 'hypothetical',
          fear: 'I have to keep checking messages',
        ),
        _rec(
          id: 'b1',
          daysAgo: 0,
          aboutness: 'hypothetical',
          fear: 'Checking messages again tonight',
        ),
      ];
      expect(const BeliefDistanceEngine().build(records).hasBelief, isFalse);
    });

    test('non-personal entries do not feed thread return personal claims', () {
      final records = _personalEvidence()
          .map(
            (r) => PressureCheckInRecord(
              entryId: r.entryId,
              createdAt: r.createdAt,
              optionId: r.optionId,
              contextIds: r.contextIds,
              fear: r.fear,
              entryAboutness: 'not_about_me',
            ),
          )
          .toList();
      expect(
        const ThreadReturnEvidenceEngine()
            .build(records, entryCount: 3)
            .hasEvidence,
        isFalse,
      );
    });

    test('non-personal entries do not feed weekly personal claims', () {
      final records = _personalEvidence()
          .map(
            (r) => PressureCheckInRecord(
              entryId: r.entryId,
              createdAt: r.createdAt,
              optionId: r.optionId,
              contextIds: r.contextIds,
              fear: r.fear,
              entryAboutness: 'research_note',
            ),
          )
          .toList();
      expect(
        const WeeklyThreadReviewEngine().build(records).hasReview,
        isFalse,
      );
    });

    test('non-personal entries do not create aha personal moments', () {
      final records = _personalEvidence()
          .map(
            (r) => PressureCheckInRecord(
              entryId: r.entryId,
              createdAt: r.createdAt,
              optionId: r.optionId,
              contextIds: r.contextIds,
              fear: r.fear,
              entryAboutness: 'hypothetical',
            ),
          )
          .toList();
      expect(
        const AhaMomentEngine().evaluate(
          records: records,
          entryCount: 3,
          trackAnalytics: false,
        ),
        isNull,
      );
    });

    test('non-personal entries do not create Pro proof personal moments', () {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'p1', aboutness: 'hypothetical'),
        entryCount: 3,
      );
      expect(ArchiveTrustReceipt.shouldShow(entryCount: 3), isFalse);
    });
  });

  group('Pack behavior', () {
    test('project material can appear inside assigned pack', () {
      const engine = ArchiveEntrySearchEngine();
      final entry = _entry(
        id: 'pack1',
        aboutness: 'project_material',
        archivePackId: 'pack_a',
      );
      final results = engine.search(
        entries: [entry],
        packs: [
          ArchivePack(
            id: 'pack_a',
            name: 'Work pack',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
        query: const ArchiveEntrySearchQuery(packId: 'pack_a'),
      );
      expect(results, hasLength(1));
    });

    test('project material does not cross packs without confirmation', () {
      final records = [
        _rec(
          id: 'a',
          daysAgo: 2,
          aboutness: 'about_me',
          archivePackId: 'pack_a',
        ),
        _rec(
          id: 'b',
          daysAgo: 1,
          aboutness: 'about_me',
          archivePackId: 'pack_b',
        ),
      ];
      final reliability = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: records,
      );
      expect(reliability.requiresCrossPackConfirmation, isTrue);
      expect(
        CrossPackConfirmation.isApproved(MemoryCardType.threadReturn.id),
        isFalse,
      );
    });
  });

  group('Search and export', () {
    test('non-personal entries remain searchable', () {
      const engine = ArchiveEntrySearchEngine();
      final entry = _entry(id: 's1', aboutness: 'hypothetical');
      final results = engine.search(
        entries: [entry],
        query: const ArchiveEntrySearchQuery(keyword: 'transcript'),
      );
      expect(results, hasLength(1));
    });

    test('entry type filter works', () {
      const engine = ArchiveEntrySearchEngine();
      final entries = [
        _entry(id: 'a', aboutness: 'about_me'),
        _entry(id: 'b', aboutness: 'hypothetical'),
      ];
      final filtered = engine.search(
        entries: entries,
        query: const ArchiveEntrySearchQuery(entryAboutnessId: 'hypothetical'),
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.entry.id, 'b');
    });

    test('entry type chip appears in search result card', () {
      const engine = ArchiveEntrySearchEngine();
      final result = engine
          .search(
            entries: [_entry(id: 'c', aboutness: 'research_note')],
            query: const ArchiveEntrySearchQuery(),
          )
          .first;
      expect(result.entryTypeLabel, EntryAboutness.researchNote.label);
    });

    test('selected export includes entry type label', () {
      const exporter = SelectedArchiveExport();
      final markdown = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'x', aboutness: 'not_about_me')],
      );
      expect(markdown, contains('Entry type: Not about me'));
      expect(markdown, isNot(contains('not_about_me')));
    });

    test('non-personal entries remain exportable', () {
      const exporter = SelectedArchiveExport();
      final markdown = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'y', aboutness: 'project_material')],
      );
      expect(markdown, contains('A long enough transcript'));
    });
  });

  group('Entry detail editing', () {
    testWidgets('entry detail can change entry type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EntryAboutnessEditor(
              entry: _entry(id: 'd1'),
              onChanged: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('entry_aboutness_editor')), findsOneWidget);
      expect(
        find.byKey(const Key('entry_detail_aboutness_hypothetical')),
        findsOneWidget,
      );
    });

    test('changing to non-personal suppresses future personal claims', () {
      final records = [
        ..._personalEvidence(),
        _rec(id: 'n1', daysAgo: 0, aboutness: 'hypothetical'),
      ];
      expect(
        const BeliefDistanceEngine().build(records, entryCount: 4).hasBelief,
        isTrue,
      );
      final onlyNonPersonal = records
          .map(
            (r) => r.entryId == 'n1'
                ? r
                : PressureCheckInRecord(
                    entryId: r.entryId,
                    createdAt: r.createdAt,
                    optionId: r.optionId,
                    contextIds: r.contextIds,
                    fear: r.fear,
                    entryAboutness: 'hypothetical',
                  ),
          )
          .toList();
      expect(
        const BeliefDistanceEngine().build(onlyNonPersonal).hasBelief,
        isFalse,
      );
    });

    test(
      'changing back to About me still requires governance before any claim',
      () {
        final decision = MemoryGovernancePolicy.evaluate(
          cardType: MemoryCardType.beliefDistance,
          records: _personalEvidence(),
          entryCount: 1,
          trackAnalytics: false,
        );
        expect(decision.allowed, isFalse);
      },
    );
  });

  group('Analytics privacy and copy', () {
    test('analytics payload contains no private content', () {
      EntryAboutnessSession.select(EntryAboutness.hypothetical, entryCount: 2);
      EntryAboutnessSession.applyToNewEntry(_entry(id: 'a1'), entryCount: 2);
      for (final event in _events) {
        for (final value in event.properties.values) {
          expect(value.toString().toLowerCase(), isNot(contains('transcript')));
        }
        if (event.properties.containsKey('entry_aboutness')) {
          expect(
            ActivationFunnelAnalytics.allowedEntryAboutnessValues.contains(
              event.properties['entry_aboutness'],
            ),
            isTrue,
          );
        }
      }
    });

    test('consumer copy has no banned words or VoiceMemory', () {
      for (final line in EntryAboutnessCopy.all) {
        final lower = line.toLowerCase();
        for (final word in _bannedWords) {
          expect(lower.contains(word.toLowerCase()), isFalse, reason: line);
        }
      }
    });

    testWidgets('receipt copy is safe', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: NotAboutMeReceipt()),
        ),
      );
      expect(find.text(EntryAboutnessCopy.nonPersonalReceipt), findsOneWidget);
    });
  });
}
