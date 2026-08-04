import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/core/config/v1_feature_flags.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_display_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_thought_map/archive_thought_map_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/archive_thought_map/archive_thought_map_engine.dart';
import 'package:voicememory_mobile/features/archive_thought_map/archive_thought_map_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_thought_map_preview_card.dart';

const _bannedPhrases = [
  'therapy',
  'mental health',
  'brain mapping',
  'treatment',
  'archiveme knows',
  '100% certainty',
];

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _repeatEntries() => [
  _entry(
    id: 'a',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'b',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'c',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

ArchiveThoughtMapPreview _preview() {
  const engine = ArchiveThoughtMapEngine();
  final preview = engine.build(_repeatEntries());
  expect(
    preview.shouldShow,
    isTrue,
    reason: 'fixture should have enough evidence',
  );
  return preview;
}

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    if (text == ArchiveThoughtMapCopy.patternSignalDisclaimer) {
      expect(lower, contains('not a diagnosis'));
      continue;
    }
    for (final phrase in _bannedPhrases) {
      expect(
        lower,
        isNot(contains(phrase)),
        reason: 'must not contain "$phrase" in "$text"',
      );
    }
    expect(
      lower,
      isNot(contains('diagnosis')),
      reason: 'unexpected diagnosis in "$text"',
    );
  }
}

void main() {
  setUp(() {
    ArchiveBeliefCorrectionStore.resetForTest();
  });

  group('ArchiveThoughtMapEngine', () {
    const engine = ArchiveThoughtMapEngine();

    test('V1 keeps thought-map previews disabled', () {
      expect(V1FeatureFlags.enableThoughtMap, isFalse);
      expect(engine.build(_repeatEntries()).shouldShow, isFalse);
    });

    test('returns hidden preview for insufficient evidence', () {
      final preview = engine.build([
        _entry(id: 'one', transcript: 'Only one saved moment so far today.'),
      ]);
      expect(preview.shouldShow, isFalse);
    });

    test(
      'builds preview with nodes and connectors when evidence exists',
      () {
        final preview = _preview();

        expect(preview.threadTitle, isNotEmpty);
        expect(preview.nodes.length, inInclusiveRange(3, 5));
        expect(preview.connectors.length, preview.nodes.length - 1);
        expect(
          preview.connectors,
          contains(ArchiveThoughtMapConnector.because),
        );
        expect(preview.savedMomentCount, 3);
        expect(preview.stageLabel, isNotNull);
        expect(preview.stageLabel, isNot(contains('%')));
        expect(
          ArchiveThoughtMapCopy.evidenceLine(preview.savedMomentCount),
          'Built from 3 saved moments',
        );
      },
      skip: !V1FeatureFlags.enableThoughtMap,
    );

    test('three unrelated entries stay hidden until threshold met', () {
      final preview = engine.build([
        _entry(
          id: 'w',
          transcript:
              'Work deadline stress piled up and I stayed late finishing slides.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'h',
          transcript:
              'Health worry kept me up — doctor appointment next week feels heavy.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'f',
          transcript:
              'Family tension at dinner — partner and I talked past each other.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ]);
      expect(preview.shouldShow, isFalse);
    });

    test(
      'named thread nodes include at least two snippets total',
      () {
        final preview = _preview();
        final snippetCount = preview.nodes.fold<int>(
          0,
          (sum, node) => sum + node.snippets.length,
        );
        expect(snippetCount, greaterThanOrEqualTo(2));
      },
      skip: !V1FeatureFlags.enableThoughtMap,
    );

    test(
      'change line uses safe summary tag when available',
      () {
        final preview = _preview();
        if (preview.changeLine != null) {
          expect(
            preview.changeLine,
            startsWith(ArchiveThoughtMapCopy.changePrefix),
          );
          expect(preview.changeLine, isNot(contains('therapy')));
        }
      },
      skip: !V1FeatureFlags.enableThoughtMap,
    );

    test('copy passes display guard and avoids banned language', () {
      _expectNoBannedCopy(ArchiveThoughtMapCopy.allVisibleStrings);
      for (final text in ArchiveThoughtMapCopy.allVisibleStrings) {
        if (text == ArchiveThoughtMapCopy.patternSignalDisclaimer) continue;
        expect(ArchiveDisplayCopyGuard.passes(text), isTrue, reason: text);
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });

    test('thought map uses watching framing not advice labels', () {
      expect(
        ArchiveThoughtMapCopy.alternativeLabel,
        'What ArchiveMe is watching next',
      );
      expect(
        ArchiveThoughtMapCopy.alternativeLabel.toLowerCase(),
        isNot(contains('what to try')),
      );
      expect(
        ArchiveThoughtMapCopy.whyNodeAppearsTitle.toLowerCase(),
        contains('evidence'),
      );
    });

    test('thought map evidence copy avoids coaching advice', () {
      final joined = [
        ArchiveThoughtMapCopy.whyNodeAppearsTitle,
        ArchiveThoughtMapCopy.nodeEvidenceFallback,
        ArchiveThoughtMapCopy.notQuiteMessage,
        ConfirmedRepeatThoughtMapCopy.title,
      ].join(' ').toLowerCase();

      expect(joined, contains('evidence'));
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('try this')));
    });

    test(
      'nodes include exact transcript snippets from saved entries',
      () {
        final preview = _preview();
        final behaviour = preview.nodes.firstWhere(
          (node) => node.kind == ArchiveThoughtMapNodeKind.behaviour,
        );

        expect(behaviour.snippets, isNotEmpty);
        expect(behaviour.supportingMomentCount, greaterThan(0));
        expect(
          behaviour.snippets.first.excerpt.toLowerCase(),
          contains('said yes'),
        );
        expect(
          _repeatEntries().any(
            (entry) =>
                entry.transcript.contains(behaviour.snippets.first.excerpt) ||
                entry.transcript.startsWith(
                  behaviour.snippets.first.excerpt.replaceAll('…', ''),
                ),
          ),
          isTrue,
        );
      },
      skip: !V1FeatureFlags.enableThoughtMap,
    );

    test(
      'uses persisted renamed title over generated title',
      () {
        final preview = _preview();
        ArchiveBeliefCorrectionStore.renameThread(
          preview.suggestionId,
          'Work yes loop',
        );

        const engine = ArchiveThoughtMapEngine();
        final rebuilt = engine.build(_repeatEntries());

        expect(rebuilt.threadTitle, 'Work yes loop');
        expect(rebuilt.suggestionId, preview.suggestionId);
      },
      skip: !V1FeatureFlags.enableThoughtMap,
    );
  });

  group('ArchiveBeliefCorrectionStore rename', () {
    test('normalizeRenamedTitle ignores empty input', () {
      expect(ArchiveBeliefCorrectionStore.normalizeRenamedTitle(''), isNull);
      expect(ArchiveBeliefCorrectionStore.normalizeRenamedTitle('   '), isNull);
    });

    test('normalizeRenamedTitle trims long titles', () {
      final long = 'A' * 200;
      final normalized = ArchiveBeliefCorrectionStore.normalizeRenamedTitle(
        long,
      );
      expect(normalized, isNotNull);
      expect(
        normalized!.length,
        ArchiveBeliefCorrectionStore.maxRenamedThreadTitleLength,
      );
    });

    test('renameThread persists through toJson and applyLoaded', () {
      ArchiveBeliefCorrectionStore.renameThread('thread_a', 'My thread');
      expect(
        ArchiveBeliefCorrectionStore.getRenamedThreadTitle('thread_a'),
        'My thread',
      );

      final json = ArchiveBeliefCorrectionStore.toJson();
      ArchiveBeliefCorrectionStore.resetForTest();
      expect(
        ArchiveBeliefCorrectionStore.getRenamedThreadTitle('thread_a'),
        isNull,
      );

      final renamed = (json['renamed'] as Map).cast<String, String>();
      ArchiveBeliefCorrectionStore.applyLoaded(
        dismissed: const [],
        saved: const [],
        renamed: renamed,
      );
      expect(
        ArchiveBeliefCorrectionStore.getRenamedThreadTitle('thread_a'),
        'My thread',
      );
    });

    test('clearRenamedThreadTitle removes stored rename', () {
      ArchiveBeliefCorrectionStore.renameThread('thread_b', 'Temporary');
      ArchiveBeliefCorrectionStore.clearRenamedThreadTitle('thread_b');
      expect(
        ArchiveBeliefCorrectionStore.getRenamedThreadTitle('thread_b'),
        isNull,
      );
    });
  });

  group('PatternsThoughtMapPreviewCard', () {
    Future<void> pumpPreviewCard(
      WidgetTester tester,
      ArchiveThoughtMapPreview preview,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PatternsThoughtMapPreviewCard(preview: preview),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders nodes, edge labels, and evidence line', (
      tester,
    ) async {
      await pumpPreviewCard(tester, _preview());

      expect(
        find.byKey(const Key('patterns_thought_map_preview_card')),
        findsOneWidget,
      );
      expect(find.text(ArchiveThoughtMapCopy.sectionTitle), findsOneWidget);
      expect(find.textContaining('Built from 3 saved moments'), findsOneWidget);
      expect(find.text(ArchiveThoughtMapCopy.connectorBecause), findsOneWidget);
      expect(find.text(ArchiveThoughtMapCopy.triggerLabel), findsOneWidget);
      expect(find.text(ArchiveThoughtMapCopy.thoughtLabel), findsOneWidget);
      expect(find.text(ArchiveThoughtMapCopy.feelsRightCta), findsOneWidget);
      expect(find.text(ArchiveThoughtMapCopy.renameThreadCta), findsOneWidget);
      expect(find.text(ArchiveThoughtMapCopy.notQuiteCta), findsOneWidget);
      _expectNoBannedCopy(
        tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? ''),
      );
    });

    testWidgets('This feels right shows confirmation state', (tester) async {
      await pumpPreviewCard(tester, _preview());

      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_feels_right')),
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_feels_right')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(ArchiveThoughtMapCopy.feelsRightConfirmation),
        findsOneWidget,
      );
      expect(find.text(ArchiveThoughtMapCopy.feelsRightCta), findsNothing);
    });

    testWidgets('Rename thread persists and shows confirmation', (
      tester,
    ) async {
      final preview = _preview();
      await pumpPreviewCard(tester, preview);

      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_rename_thread')),
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_rename_thread')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('patterns_thought_map_rename_field')),
        'Work yes loop',
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_rename_save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work yes loop'), findsOneWidget);
      expect(
        find.text(ArchiveThoughtMapCopy.threadRenamedConfirmation),
        findsOneWidget,
      );
      expect(
        ArchiveBeliefCorrectionStore.getRenamedThreadTitle(
          preview.suggestionId,
        ),
        'Work yes loop',
      );

      const engine = ArchiveThoughtMapEngine();
      final rebuilt = engine.build(_repeatEntries());
      expect(rebuilt.threadTitle, 'Work yes loop');

      await pumpPreviewCard(tester, rebuilt);
      expect(find.text('Work yes loop'), findsOneWidget);
      expect(
        find.byKey(const Key('patterns_thought_map_rename_field')),
        findsNothing,
      );
    });

    testWidgets('empty rename is ignored', (tester) async {
      final preview = _preview();
      final originalTitle = preview.threadTitle;
      await pumpPreviewCard(tester, preview);

      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_rename_thread')),
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_rename_thread')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('patterns_thought_map_rename_field')),
        '   ',
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_rename_save')),
      );
      await tester.pumpAndSettle();

      expect(find.text(originalTitle), findsOneWidget);
      expect(
        find.text(ArchiveThoughtMapCopy.threadRenamedConfirmation),
        findsNothing,
      );
      expect(
        ArchiveBeliefCorrectionStore.getRenamedThreadTitle(
          preview.suggestionId,
        ),
        isNull,
      );
    });

    testWidgets('long rename is trimmed to store limit', (tester) async {
      final preview = _preview();
      final longTitle = 'B' * 200;
      final expected = ArchiveBeliefCorrectionStore.normalizeRenamedTitle(
        longTitle,
      )!;

      await pumpPreviewCard(tester, preview);
      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_rename_thread')),
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_rename_thread')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('patterns_thought_map_rename_field')),
        longTitle,
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_rename_save')),
      );
      await tester.pumpAndSettle();

      expect(find.text(expected), findsOneWidget);
      expect(
        ArchiveBeliefCorrectionStore.getRenamedThreadTitle(
          preview.suggestionId,
        ),
        expected,
      );
    });

    testWidgets('Not quite shows wait-for-more-evidence copy', (tester) async {
      await pumpPreviewCard(tester, _preview());

      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_not_quite')),
      );
      await tester.tap(find.byKey(const Key('patterns_thought_map_not_quite')));
      await tester.pumpAndSettle();

      expect(find.text(ArchiveThoughtMapCopy.notQuiteMessage), findsOneWidget);
      expect(find.text(ArchiveThoughtMapCopy.notQuiteCta), findsNothing);
    });

    testWidgets('tapping Trigger opens evidence panel with saved moments', (
      tester,
    ) async {
      await pumpPreviewCard(tester, _preview());

      expect(
        find.byKey(const Key('patterns_thought_map_evidence_panel')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_node_tap_trigger')),
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_node_tap_trigger')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(ArchiveThoughtMapCopy.whyNodeAppearsTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('patterns_thought_map_evidence_panel')),
        findsOneWidget,
      );
      expect(find.text(ArchiveThoughtMapCopy.triggerLabel), findsWidgets);
      expect(find.textContaining('Built from'), findsWidgets);
      expect(find.textContaining('said yes'), findsWidgets);
      expect(
        find.text(ArchiveThoughtMapCopy.patternSignalDisclaimer),
        findsOneWidget,
      );
      _expectNoBannedCopy(
        tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? ''),
      );
    });

    testWidgets('switching nodes updates evidence panel', (tester) async {
      await pumpPreviewCard(tester, _preview());

      await tester.tap(
        find.byKey(const Key('patterns_thought_map_node_tap_trigger')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('patterns_thought_map_evidence_panel')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('patterns_thought_map_node_tap_behaviour')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const Key('patterns_thought_map_evidence_node_label_behaviour'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('close hides evidence panel', (tester) async {
      await pumpPreviewCard(tester, _preview());

      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_node_tap_trigger')),
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_node_tap_trigger')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('patterns_thought_map_evidence_panel')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('patterns_thought_map_evidence_close')),
      );
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_evidence_close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('patterns_thought_map_evidence_panel')),
        findsNothing,
      );
    });

    testWidgets('node with no snippets shows cautious fallback', (
      tester,
    ) async {
      final base = _preview();
      final emptyNode = ArchiveThoughtMapNode(
        id: 'test_empty_relief',
        kind: ArchiveThoughtMapNodeKind.relief,
        label: ArchiveThoughtMapCopy.reliefLabel,
        value: 'Test relief node',
        supportingMomentCount: 0,
        snippets: const [],
      );
      final preview = ArchiveThoughtMapPreview(
        shouldShow: true,
        threadTitle: base.threadTitle,
        nodes: [emptyNode],
        connectors: const [],
        savedMomentCount: base.savedMomentCount,
        suggestionId: base.suggestionId,
      );

      await pumpPreviewCard(tester, preview);
      await tester.tap(
        find.byKey(const Key('patterns_thought_map_node_tap_relief')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(ArchiveThoughtMapCopy.nodeEvidenceFallback),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveThoughtMapCopy.patternSignalDisclaimer),
        findsOneWidget,
      );
    });

    testWidgets('Record another moment routes to record not evidence', (
      tester,
    ) async {
      var recordOpened = false;
      final router = GoRouter(
        initialLocation: '/patterns',
        routes: [
          GoRoute(
            path: '/patterns',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: PatternsThoughtMapPreviewCard(preview: _preview()),
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) {
              recordOpened = true;
              return const Scaffold(body: Text('RECORD_SCREEN'));
            },
          ),
          GoRoute(
            path: '/belief-evidence',
            builder: (context, state) =>
                const Scaffold(body: Text('EVIDENCE_SCREEN')),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(402, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('patterns_thought_map_node_tap_trigger')),
      );
      await tester.pumpAndSettle();
      final recordCta = find.byKey(
        const Key('patterns_thought_map_record_another_moment'),
      );
      await tester.ensureVisible(recordCta);
      await tester.tap(recordCta);
      await tester.pumpAndSettle();

      expect(recordOpened, isTrue);
      expect(find.text('RECORD_SCREEN'), findsOneWidget);
      expect(find.text('EVIDENCE_SCREEN'), findsNothing);
    });
  }, skip: !V1FeatureFlags.enableThoughtMap);
}
