import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_items/archive_action_item.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/export/selected_archive_export.dart';
import 'package:voicememory_mobile/features/memory/archive_evidence_policy.dart';
import 'package:voicememory_mobile/features/memory/archive_evidence_record.dart';
import 'package:voicememory_mobile/features/memory/archive_evidence_type.dart';
import 'package:voicememory_mobile/features/memory/curated_memory_marker.dart';
import 'package:voicememory_mobile/features/memory/curated_memory_preservation_policy.dart';
import 'package:voicememory_mobile/features/memory/keep_exact_details.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_frame.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_governance_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_surfacing_mode.dart';
import 'package:voicememory_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/memory/curated_memory_receipt.dart';
import 'package:voicememory_mobile/widgets/memory/entry_options_section.dart';

import 'support/expand_advanced_save_options.dart';
import 'package:voicememory_mobile/widgets/memory/memory_evidence_inspect_sheet.dart';
import 'package:voicememory_mobile/widgets/memory/preserve_original_control.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';

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
  String transcript = 'A long enough transcript for archive search and export.',
  bool preserveOriginal = false,
  bool keepExactDetails = false,
  bool isPinned = false,
  bool connectionApproved = false,
  String aboutness = 'about_me',
  String surfacing = 'normal',
  bool treatAsNew = false,
  bool keepSeparate = false,
  String? archivePackId,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12),
  transcript: transcript,
  durationSeconds: 12,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Generated observation summary.',
    repeatedSignal: 'signal',
  ),
  preserveOriginal: preserveOriginal,
  keepExactDetails: keepExactDetails,
  isPinned: isPinned,
  connectionApproved: connectionApproved,
  entryAboutness: aboutness,
  memorySurfacing: surfacing,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
  archivePackId: archivePackId,
);

PressureCheckInRecord _rec({
  required String id,
  bool preserveOriginal = false,
  bool keepExactDetails = false,
  String surfacing = 'normal',
  String aboutness = 'about_me',
  bool treatAsNew = false,
  bool keepSeparate = false,
  bool connectionApproved = false,
  String? fear,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  optionId: 'could_not_stop',
  contextIds: const ['work'],
  fear: fear ?? 'Specific wording about a work decision',
  preserveOriginal: preserveOriginal,
  keepExactDetails: keepExactDetails,
  memorySurfacing: surfacing,
  entryAboutness: aboutness,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
  connectionApproved: connectionApproved,
);

void _reset() {
  MemoryScopePolicy.resetForTest();
  MemoryGovernancePolicy.resetForTest();
  PreserveOriginalSession.resetSessionForTest();
  KeepExactDetails.resetSessionForTest();
  MemoryAuthorityFrameLog.resetForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

void main() {
  setUp(_reset);

  group('Preserve original control', () {
    testWidgets('renders in entry options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
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
      expect(
        find.byKey(const Key('preserve_original_control')),
        findsOneWidget,
      );
      expect(
        find.text(CuratedMemoryCopy.preserveOriginalLabel),
        findsOneWidget,
      );
    });

    test('persists on save via session', () {
      PreserveOriginalSession.select(true, entryCount: 2);
      final saved = PreserveOriginalSession.applyToNewEntry(
        _entry(id: 'p1'),
        entryCount: 2,
      );
      expect(saved.preserveOriginal, isTrue);
    });

    testWidgets('can be changed in entry detail editor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PreserveOriginalEditor(
              entry: _entry(id: 'd1'),
              onChanged: () {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(const Key('preserve_original_control')),
        findsOneWidget,
      );
    });
  });

  group('Curated evidence sources', () {
    test('keep exact details applies preservation policy', () {
      KeepExactDetails.selectedForNextSave = true;
      final saved = KeepExactDetails.applyToNewEntry(
        _entry(id: 'k1'),
        entryCount: 2,
      );
      expect(saved.keepExactDetails, isTrue);
      expect(saved.preserveOriginal, isTrue);
      expect(
        _events.any(
          (e) =>
              e.name ==
              ActivationFunnelAnalytics.curatedMemoryPreservationApplied,
        ),
        isTrue,
      );
    });

    test('pinned entry is treated as curated evidence', () {
      expect(
        CuratedMemoryMarker.isCurated(_entry(id: 'pin', isPinned: true)),
        isTrue,
      );
      expect(
        CuratedMemoryMarker.sourceFor(_entry(id: 'pin', isPinned: true)),
        CuratedPreservationSource.pin,
      );
    });

    test('action item source is treated as curated evidence', () {
      final items = [
        ArchiveActionItem(
          id: 'a1',
          sourceEntryId: 'e1',
          title: 'Follow up',
          note: '',
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
          status: ActionItemStatus.open,
        ),
      ];
      expect(
        CuratedMemoryMarker.isCurated(_entry(id: 'e1'), hasActionItem: true),
        isTrue,
      );
      expect(CuratedMemoryMarker.hasActionItemForEntry('e1', items), isTrue);
    });

    test('user-confirmed connection is treated as curated evidence', () {
      expect(
        CuratedMemoryMarker.isCurated(
          _entry(id: 'c1', connectionApproved: true),
        ),
        isTrue,
      );
      expect(
        CuratedMemoryMarker.sourceFor(
          _entry(id: 'c1', connectionApproved: true),
        ),
        CuratedPreservationSource.userConfirmedConnection,
      );
    });
  });

  group('Summary separation', () {
    test('generated summary cannot replace preserved original in export', () {
      const exporter = SelectedArchiveExport();
      final md = exporter.buildMarkdown(
        selectedEntries: [
          _entry(
            id: 'x1',
            preserveOriginal: true,
            transcript: 'Exact user wording that matters.',
          ),
        ],
      );
      expect(md, contains('Exact user wording that matters.'));
      expect(md, contains('Original preserved: Yes'));
      expect(md, contains('### Generated summary'));
    });

    test('generated interpretation is not source of truth', () {
      final evidence = [
        ArchiveEvidenceRecord(
          entryId: 'i1',
          type: ArchiveEvidenceType.interpretation,
          createdAt: DateTime(2026, 6, 12),
        ),
        ArchiveEvidenceRecord(
          entryId: 'p1',
          type: ArchiveEvidenceType.preservedOriginal,
          createdAt: DateTime(2026, 6, 12),
        ),
      ];
      final sources = ArchiveEvidencePolicy.sourceEvidence(evidence);
      expect(sources.every((e) => e.type.canBeSourceOfTruth), isTrue);
      expect(
        sources.any((e) => e.type == ArchiveEvidenceType.interpretation),
        isFalse,
      );
      expect(
        CuratedMemoryPreservationPolicy.interpretationCanBeHighAuthority(
          evidence,
        ),
        isFalse,
      );
    });

    test(
      'selected export does not output only summary for preserved entry',
      () {
        const exporter = SelectedArchiveExport();
        final md = exporter.buildMarkdown(
          selectedEntries: [_entry(id: 'only', preserveOriginal: true)],
        );
        expect(md, contains('transcript'));
        expect(md.split('Generated summary').length, greaterThan(1));
      },
    );
  });

  group('Evidence inspection', () {
    testWidgets('preserved original appears as original evidence section', (
      tester,
    ) async {
      const engine = MemoryAuthorityFramingEngine();
      engine.frame([
        _rec(id: 'ev1', preserveOriginal: true),
        _rec(id: 'ev2', preserveOriginal: true),
        _rec(id: 'ev3', preserveOriginal: true),
      ], cardType: MemoryCardType.threadReturn);
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MemoryEvidenceInspectSheet(
              cardType: MemoryCardType.threadReturn,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('original_evidence_block')), findsOneWidget);
      expect(
        find.text(CuratedMemoryCopy.originalEvidenceSectionTitle),
        findsOneWidget,
      );
    });

    test(
      'user-initiated evidence inspection can open source entry analytics',
      () {
        CuratedMemoryPreservationPolicy.trackOriginalOpened(
          source: 'evidence_inspection',
          preservationSource: CuratedPreservationSource.manual,
        );
        expect(
          _events.any(
            (e) => e.name == ActivationFunnelAnalytics.originalEvidenceOpened,
          ),
          isTrue,
        );
      },
    );
  });

  group('Proactive cards', () {
    testWidgets('do not show full original text by default', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const threadEngine = ThreadReturnEvidenceEngine();
      final records = [
        _rec(
          id: 't1',
          preserveOriginal: true,
          fear: 'I keep circling the same work decision',
        ),
        _rec(
          id: 't2',
          preserveOriginal: true,
          fear: 'The same work decision came back today',
        ),
        _rec(
          id: 't3',
          preserveOriginal: true,
          fear: 'Circling the same work decision tonight',
        ),
      ];
      final evidence = threadEngine.build(records, entryCount: 3);
      expect(evidence.hasEvidence, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ThreadReturnEvidenceCard(evidence: evidence)),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Specific wording about'), findsNothing);
    });
  });

  group('Search and export', () {
    test('search filter Preserved original works', () {
      const engine = ArchiveEntrySearchEngine();
      final entries = [
        _entry(id: 'a', preserveOriginal: true),
        _entry(id: 'b'),
      ];
      final results = engine.search(
        entries: entries,
        query: const ArchiveEntrySearchQuery(preservedOriginalOnly: true),
      );
      expect(results, hasLength(1));
      expect(results.first.entry.id, 'a');
    });

    test('result card metadata includes Original preserved chip', () {
      const engine = ArchiveEntrySearchEngine();
      final results = engine.search(
        entries: [_entry(id: 'chip', preserveOriginal: true)],
        query: const ArchiveEntrySearchQuery(),
      );
      expect(
        results.first.preservedOriginalLabel,
        CuratedMemoryCopy.searchChipLabel,
      );
    });

    test('selected export includes Original preserved label', () {
      const exporter = SelectedArchiveExport();
      final md = exporter.buildMarkdown(
        selectedEntries: [_entry(id: 'exp', preserveOriginal: true)],
      );
      expect(md, contains('Original preserved: Yes'));
    });
  });

  group('Governance safeguards', () {
    test('preserve original does not override Do not surface', () {
      final entry = _entry(
        id: 'dns',
        preserveOriginal: true,
        surfacing: 'do_not_surface',
      );
      expect(
        SensitiveSurfacingPolicy.evaluate(
          mode: MemorySurfacingMode.doNotSurface,
          surfaceType: MemorySurfaceType.threadReturn,
        ),
        SensitiveSurfacingOutcome.blocked,
      );
      expect(SensitiveSurfacingPolicy.isDoNotSurfaceEntry(entry), isTrue);
    });

    test('preserve original does not override Sensitive cautious behavior', () {
      final entry = _entry(
        id: 'sens',
        preserveOriginal: true,
        surfacing: 'sensitive',
      );
      expect(
        SensitiveSurfacingPolicy.evaluate(
          mode: MemorySurfacingMode.sensitive,
          surfaceType: MemorySurfaceType.threadReturn,
        ),
        SensitiveSurfacingOutcome.blocked,
      );
      expect(SensitiveSurfacingPolicy.isSensitiveEntry(entry), isTrue);
    });

    test('preserve original does not override Not about me / Hypothetical', () {
      final records = [
        _rec(id: 'h1', preserveOriginal: true, aboutness: 'hypothetical'),
        _rec(id: 'h2', preserveOriginal: true, aboutness: 'hypothetical'),
        _rec(id: 'h3', preserveOriginal: true, aboutness: 'hypothetical'),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });

    test(
      'preserve original does not override Keep separate / Treat as new',
      () {
        final records = [
          _rec(id: 'f1', preserveOriginal: true, treatAsNew: true),
        ];
        const engine = MemoryAuthorityFramingEngine();
        final framing = engine.frame(
          records,
          cardType: MemoryCardType.threadReturn,
        );
        expect(framing.candidates, isEmpty);
      },
    );

    test('preserve original does not automatically create personal claims', () {
      const engine = MemoryAuthorityFramingEngine();
      final framing = engine.frame([
        _rec(id: 'n1', preserveOriginal: true),
        _rec(id: 'n2', preserveOriginal: true),
        _rec(id: 'n3', preserveOriginal: true),
      ], cardType: MemoryCardType.threadReturn);
      expect(
        framing.frame.authorityState,
        isNot(MemoryAuthorityState.confirmed),
      );
    });

    test('generated summaries cannot become high-authority evidence', () {
      final evidence = [
        ArchiveEvidenceRecord(
          entryId: 'g1',
          type: ArchiveEvidenceType.interpretation,
          createdAt: DateTime(2026, 6, 12),
        ),
        ArchiveEvidenceRecord(
          entryId: 'g2',
          type: ArchiveEvidenceType.preservedOriginal,
          createdAt: DateTime(2026, 6, 12),
        ),
      ];
      expect(
        CuratedMemoryPreservationPolicy.interpretationCanBeHighAuthority(
          evidence,
        ),
        isFalse,
      );
    });

    test('blocks proactive boost for preserved entries', () {
      expect(
        CuratedMemoryPreservationPolicy.blocksProactiveBoost(
          _entry(id: 'b1', preserveOriginal: true),
        ),
        isTrue,
      );
    });
  });

  group('Analytics and copy guardrails', () {
    test('preserve_original_selected tracked without private content', () {
      PreserveOriginalSession.select(true, entryCount: 2);
      final event = _events.last;
      expect(event.name, ActivationFunnelAnalytics.preserveOriginalSelected);
      expect(event.properties.containsKey('preservation_source'), isTrue);
      for (final value in event.properties.values) {
        expect(value.toString().toLowerCase(), isNot(contains('transcript')));
      }
    });

    test('analytics payload contains no private content', () {
      PreserveOriginalSession.select(true, entryCount: 2);
      PreserveOriginalSession.applyToNewEntry(_entry(id: 'a'), entryCount: 2);
      CuratedMemoryPreservationPolicy.trackOriginalOpened(
        source: 'evidence_inspection',
        preservationSource: CuratedPreservationSource.manual,
      );
      for (final event in _events) {
        for (final value in event.properties.values) {
          expect(value.toString().toLowerCase(), isNot(contains('transcript')));
          expect(value.toString().toLowerCase(), isNot(contains('wording')));
        }
      }
    });

    test('banned-word sweep on consumer copy', () {
      for (final line in CuratedMemoryCopy.all) {
        final lower = line.toLowerCase();
        for (final word in _bannedWords) {
          expect(lower, isNot(contains(word.toLowerCase())));
        }
      }
      for (final line in [
        MemoryEvidenceInspectCopy.sheetTitle,
        MemoryEvidenceInspectCopy.footer,
      ]) {
        final lower = line.toLowerCase();
        for (final word in _bannedWords) {
          expect(lower, isNot(contains(word.toLowerCase())));
        }
      }
    });

    testWidgets('receipt shows Original preserved', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CuratedMemoryReceipt()),
        ),
      );
      expect(find.text(CuratedMemoryCopy.savedReceipt), findsOneWidget);
    });
  });
}
