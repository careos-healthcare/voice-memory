import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/export/selected_archive_export.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_governance_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:voicememory_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/features/trust/archive_trust_receipt.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/memory/do_not_surface_receipt.dart';
import 'package:voicememory_mobile/widgets/memory/entry_options_section.dart';

import 'support/expand_advanced_save_options.dart';
import 'package:voicememory_mobile/widgets/memory/memory_surfacing_editor.dart';
import 'package:voicememory_mobile/widgets/memory/sensitive_surfacing_receipt.dart';

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
  'trauma',
  'traumatic',
  'painful',
  'VoiceMemory',
];

JournalEntry _entry({
  required String id,
  String surfacing = 'normal',
  String aboutness = 'about_me',
  String? archivePackId,
  bool isPinned = false,
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
  memorySurfacing: surfacing,
  archivePackId: archivePackId,
  isPinned: isPinned,
);

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  String surfacing = 'normal',
  String aboutness = 'about_me',
  String? fear,
  String? archivePackId,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: const ['work'],
  fear: fear,
  archivePackId: archivePackId,
  entryAboutness: aboutness,
  memorySurfacing: surfacing,
);

List<PressureCheckInRecord> _threadRecords({String surfacing = 'normal'}) => [
  _rec(
    id: 'e1',
    daysAgo: 6,
    surfacing: surfacing,
    fear: 'I keep circling the same work decision',
  ),
  _rec(
    id: 'e2',
    daysAgo: 3,
    surfacing: surfacing,
    fear: 'The same work decision came back today',
  ),
  _rec(
    id: 'e3',
    daysAgo: 0,
    surfacing: surfacing,
    fear: 'Circling the same work decision tonight',
  ),
];

void _reset() {
  MemoryScopePolicy.resetForTest();
  MemoryGovernancePolicy.resetForTest();
  MemorySurfacingSession.resetSessionForTest();
  ArchiveTrustReceipt.resetForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

void main() {
  setUp(_reset);

  group('Surfacing picker', () {
    testWidgets('renders under entry options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
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
      expect(find.byKey(const Key('memory_surfacing_picker')), findsOneWidget);
      expect(find.text('Surfacing'), findsWidgets);
    });

    test('default surfacing is Normal', () {
      expect(MemorySurfacingSession.selected, MemorySurfacingMode.normal);
    });
  });

  group('Save persistence', () {
    JournalEntry saveWith(MemorySurfacingMode mode) {
      MemorySurfacingSession.select(mode, entryCount: 2);
      return MemorySurfacingSession.applyToNewEntry(
        _entry(id: 'save1'),
        entryCount: 2,
      );
    }

    test('selecting Sensitive persists on save', () {
      final saved = saveWith(MemorySurfacingMode.sensitive);
      expect(saved.memorySurfacing, 'sensitive');
    });

    test('selecting Do not surface persists on save', () {
      final saved = saveWith(MemorySurfacingMode.doNotSurface);
      expect(saved.memorySurfacing, 'do_not_surface');
    });
  });

  group('Search and export', () {
    test('Sensitive entry remains searchable', () {
      const engine = ArchiveEntrySearchEngine();
      final results = engine.search(
        entries: [_entry(id: 's1', surfacing: 'sensitive')],
        query: const ArchiveEntrySearchQuery(keyword: 'transcript'),
      );
      expect(results, hasLength(1));
    });

    test('Do not surface entry remains searchable', () {
      const engine = ArchiveEntrySearchEngine();
      final results = engine.search(
        entries: [_entry(id: 's2', surfacing: 'do_not_surface')],
        query: const ArchiveEntrySearchQuery(keyword: 'transcript'),
      );
      expect(results, hasLength(1));
    });

    test('Sensitive entry remains exportable', () {
      const exporter = SelectedArchiveExport();
      final md = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'e1', surfacing: 'sensitive')],
      );
      expect(md, contains('transcript'));
      expect(md, contains('- Surfacing: Sensitive'));
    });

    test('Do not surface entry remains exportable', () {
      const exporter = SelectedArchiveExport();
      final md = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'e2', surfacing: 'do_not_surface')],
      );
      expect(md, contains('transcript'));
      expect(md, contains('- Surfacing: Do not surface'));
    });

    test('selected export includes surfacing label', () {
      const exporter = SelectedArchiveExport();
      final md = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'e3', surfacing: 'normal')],
      );
      expect(md, contains('- Surfacing: Normal'));
    });

    test('search filter by Sensitive works', () {
      const engine = ArchiveEntrySearchEngine();
      final entries = [
        _entry(id: 'a', surfacing: 'sensitive'),
        _entry(id: 'b', surfacing: 'normal'),
      ];
      final results = engine.search(
        entries: entries,
        query: const ArchiveEntrySearchQuery(memorySurfacingId: 'sensitive'),
      );
      expect(results.map((r) => r.entry.id), ['a']);
    });

    test('search filter by Do not surface works', () {
      const engine = ArchiveEntrySearchEngine();
      final entries = [
        _entry(id: 'a', surfacing: 'do_not_surface'),
        _entry(id: 'b', surfacing: 'normal'),
      ];
      final results = engine.search(
        entries: entries,
        query: const ArchiveEntrySearchQuery(
          memorySurfacingId: 'do_not_surface',
        ),
      );
      expect(results.map((r) => r.entry.id), ['a']);
    });

    test('result cards show local surfacing chip', () {
      const engine = ArchiveEntrySearchEngine();
      final result = engine
          .search(
            entries: [_entry(id: 'c', surfacing: 'do_not_surface')],
            query: const ArchiveEntrySearchQuery(),
          )
          .single;
      expect(result.surfacingLabel, 'Do not surface');
    });
  });

  group('Proactive memory exclusion', () {
    test('Do not surface does not feed Aha Moment Engine', () {
      expect(
        const AhaMomentEngine().evaluate(
          records: _threadRecords(surfacing: 'do_not_surface'),
          entryCount: 3,
          trackAnalytics: false,
        ),
        isNull,
      );
    });

    test('Do not surface does not feed Thread Return proactive card', () {
      expect(
        const ThreadReturnEvidenceEngine()
            .build(_threadRecords(surfacing: 'do_not_surface'), entryCount: 3)
            .hasEvidence,
        isFalse,
      );
    });

    test('Do not surface does not feed Weekly Review proactive section', () {
      expect(
        const WeeklyThreadReviewEngine()
            .build(_threadRecords(surfacing: 'do_not_surface'))
            .hasReview,
        isFalse,
      );
    });

    test('Do not surface does not feed Belief Distance', () {
      final records = [
        _rec(
          id: 'b0',
          daysAgo: 4,
          surfacing: 'do_not_surface',
          fear: 'I have to keep checking messages',
        ),
        _rec(
          id: 'b1',
          daysAgo: 0,
          surfacing: 'do_not_surface',
          fear: 'Checking messages again tonight',
        ),
      ];
      expect(const BeliefDistanceEngine().build(records).hasBelief, isFalse);
    });

    test('Do not surface does not feed Pro proof/share moments', () {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'p1', surfacing: 'do_not_surface'),
        entryCount: 3,
      );
      expect(ArchiveTrustReceipt.shouldShow(entryCount: 3), isFalse);
    });

    test('Sensitive does not drive aha moment by itself', () {
      expect(
        const AhaMomentEngine().evaluate(
          records: _threadRecords(surfacing: 'sensitive'),
          entryCount: 3,
          trackAnalytics: false,
        ),
        isNull,
      );
    });

    test('Sensitive does not drive Pro proof/share card', () {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'p2', surfacing: 'sensitive'),
        entryCount: 3,
      );
      expect(ArchiveTrustReceipt.shouldShow(entryCount: 3), isFalse);
    });
  });

  group('User-initiated access', () {
    test('Do not surface can be opened directly', () {
      final outcome = SensitiveSurfacingPolicy.evaluate(
        mode: MemorySurfacingMode.doNotSurface,
        surfaceType: MemorySurfaceType.directOpen,
        userInitiated: true,
      );
      expect(outcome, SensitiveSurfacingOutcome.userInitiatedOnly);
    });

    test('Do not surface can appear in selected export', () {
      final outcome = SensitiveSurfacingPolicy.evaluate(
        mode: MemorySurfacingMode.doNotSurface,
        surfaceType: MemorySurfaceType.selectedExport,
        userInitiated: true,
      );
      expect(outcome, SensitiveSurfacingOutcome.userInitiatedOnly);
    });

    test('Do not surface can appear in pack detail', () {
      final outcome = SensitiveSurfacingPolicy.evaluate(
        mode: MemorySurfacingMode.doNotSurface,
        surfaceType: MemorySurfaceType.packDetail,
        userInitiated: true,
      );
      expect(outcome, SensitiveSurfacingOutcome.userInitiatedOnly);
    });

    test('Do not surface can appear in pinned screen if user pinned it', () {
      final outcome = SensitiveSurfacingPolicy.evaluate(
        mode: MemorySurfacingMode.doNotSurface,
        surfaceType: MemorySurfaceType.pinnedScreen,
        userInitiated: true,
      );
      expect(outcome, SensitiveSurfacingOutcome.userInitiatedOnly);
    });

    test(
      'Do not surface can appear in action items if user created action item',
      () {
        final outcome = SensitiveSurfacingPolicy.evaluate(
          mode: MemorySurfacingMode.doNotSurface,
          surfaceType: MemorySurfaceType.actionItems,
          userInitiated: true,
        );
        expect(outcome, SensitiveSurfacingOutcome.userInitiatedOnly);
      },
    );

    test(
      'Sensitive can appear in user-initiated evidence inspection with cautious state',
      () {
        final outcome = SensitiveSurfacingPolicy.evaluate(
          mode: MemorySurfacingMode.sensitive,
          surfaceType: MemorySurfaceType.evidenceInspection,
          userInitiated: true,
        );
        expect(outcome, SensitiveSurfacingOutcome.cautious);
      },
    );

    test(
      'Sensitive does not outrank normal evidence because of emotional weight',
      () {
        final records = [
          _rec(id: 'n', daysAgo: 1, surfacing: 'normal'),
          _rec(id: 's', daysAgo: 0, surfacing: 'sensitive'),
        ];
        final eligible = SensitiveSurfacingPolicy.proactiveClaimEligible(
          records,
        );
        expect(eligible.map((r) => r.entryId), ['n']);
      },
    );
  });

  group('Governance overrides', () {
    test('changing to Do not surface suppresses future proactive cards', () {
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _threadRecords(surfacing: 'do_not_surface'),
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });

    test(
      'changing back to Normal still requires governance/priority/authority',
      () {
        MemorySurfacingSession.select(
          MemorySurfacingMode.normal,
          entryCount: 3,
        );
        final decision = MemoryGovernancePolicy.evaluate(
          cardType: MemoryCardType.threadReturn,
          records: _threadRecords(surfacing: 'normal'),
          entryCount: 3,
          source: 'record',
          trackAnalytics: false,
        );
        expect(decision.allowed, isTrue);
      },
    );

    test('memory off still blocks memory use', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _threadRecords(),
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });

    test('treat as new still overrides surfacing', () {
      final record = PressureCheckInRecord(
        entryId: 't',
        createdAt: DateTime.now(),
        optionId: 'could_not_stop',
        contextIds: const ['work'],
        fear: 'work loop',
        treatAsNew: true,
        memorySurfacing: 'normal',
      );
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: [record],
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });

    test('keep separate still overrides surfacing', () {
      final record = PressureCheckInRecord(
        entryId: 'k',
        createdAt: DateTime.now(),
        optionId: 'could_not_stop',
        keepSeparate: true,
        memorySurfacing: 'normal',
      );
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: [record],
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });

    test('hypothetical still blocks personal claims', () {
      final records = _threadRecords().map(
        (r) => PressureCheckInRecord(
          entryId: r.entryId,
          createdAt: r.createdAt,
          optionId: r.optionId,
          contextIds: r.contextIds,
          fear: r.fear,
          entryAboutness: 'hypothetical',
          memorySurfacing: 'normal',
        ),
      );
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records.toList(),
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });
  });

  group('Entry detail editing', () {
    testWidgets('entry detail can change entry type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MemorySurfacingEditor(
              entry: _entry(id: 'd1'),
              onChanged: () {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('memory_surfacing_editor')), findsOneWidget);
    });
  });

  group('Receipts', () {
    testWidgets('Do not surface receipt copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DoNotSurfaceReceipt()),
        ),
      );
      expect(
        find.text(MemorySurfacingCopy.doNotSurfaceReceipt),
        findsOneWidget,
      );
    });

    testWidgets('Sensitive receipt copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SensitiveSurfacingReceipt()),
        ),
      );
      expect(find.text(MemorySurfacingCopy.sensitiveReceipt), findsOneWidget);
    });
  });

  group('Privacy and copy guardrails', () {
    test('analytics payload contains no private content', () {
      MemorySurfacingSession.select(
        MemorySurfacingMode.doNotSurface,
        entryCount: 2,
      );
      MemorySurfacingSession.applyToNewEntry(_entry(id: 'a'), entryCount: 2);
      for (final event in _events) {
        for (final value in event.properties.values) {
          expect(value.toString().toLowerCase(), isNot(contains('transcript')));
          expect(
            value.toString().toLowerCase(),
            isNot(contains('confidential')),
          );
        }
      }
    });

    test('no VoiceMemory in consumer-facing copy', () {
      for (final line in MemorySurfacingCopy.all) {
        expect(line.toLowerCase(), isNot(contains('voicememory')));
      }
    });

    test('banned-word sweep over all new consumer copy', () {
      for (final line in MemorySurfacingCopy.all) {
        final lower = line.toLowerCase();
        for (final word in _bannedWords) {
          expect(lower, isNot(contains(word.toLowerCase())));
        }
      }
    });
  });
}
