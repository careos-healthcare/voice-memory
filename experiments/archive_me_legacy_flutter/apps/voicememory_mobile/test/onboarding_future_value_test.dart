import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/config/v1_navigation_guard.dart';
import 'package:voicememory_mobile/features/onboarding_future_value/future_preview_screen.dart';
import 'package:voicememory_mobile/features/onboarding_future_value/onboarding_future_value_copy.dart';
import 'package:voicememory_mobile/features/onboarding_future_value/onboarding_future_value_fixtures.dart';
import 'package:voicememory_mobile/widgets/record/record_first_run_promise_card.dart';

Widget _app({
  FuturePreviewAction? onExit,
  FuturePreviewAction? onStart,
  FuturePreviewEvent? onEvent,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  double textScale = 1,
  Size size = const Size(320, 568),
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
        textScaler: TextScaler.linear(textScale),
      ),
      child: FuturePreviewScreen(
        onExit: onExit,
        onStart: onStart,
        onEvent: onEvent ?? (_) {},
      ),
    ),
  );
}

Future<void> _goToStage(WidgetTester tester, int index) async {
  final chip = find.byKey(Key('future_preview_stage_chip_$index'));
  await Scrollable.ensureVisible(tester.element(chip), alignment: 0.5);
  await tester.pump();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _dismissSheet(WidgetTester tester, Finder sheet) async {
  Navigator.of(tester.element(sheet)).pop();
  await tester.pumpAndSettle();
}

void main() {
  group('isolated deterministic fixtures', () {
    test('all IDs are scoped and conclusions pass the strict render gate', () {
      final fixtures = OnboardingFutureValueFixtures.sample;

      expect(
        fixtures.allIds,
        everyElement(startsWith(OnboardingFutureValueFixtures.idPrefix)),
      );
      expect(fixtures.graph.schemaVersion, 2);
      expect(fixtures.graph.nodes, hasLength(5));
      expect(fixtures.validatedOneMoment.value.confidence, lessThan(50));
      expect(fixtures.validatedThreeMoment.value.historyVersion, 2);
      expect(fixtures.validatedFiveMoment.value.historyVersion, 3);
      expect(
        fixtures.validatedFiveMoment.value.provenance.source,
        contains('illustrative'),
      );
    });

    test('graph and conclusion evidence use exact UTF-16 slices', () {
      final fixtures = OnboardingFutureValueFixtures.sample;
      final nodeIds = fixtures.graph.nodes.map((node) => node.id).toSet();

      for (final node in fixtures.graph.nodes) {
        expect(node.hasValidEvidence, isTrue);
        for (final evidence in node.evidence) {
          expect(
            evidence.isExactSliceOf(
              fixtures.canonicalTranscripts[evidence.entryId]!,
            ),
            isTrue,
          );
        }
      }
      for (final edge in fixtures.graph.edges) {
        expect(nodeIds, contains(edge.sourceNodeId));
        expect(nodeIds, contains(edge.targetNodeId));
        expect(edge.hasValidEvidence, isTrue);
        for (final evidence in edge.evidence) {
          expect(
            evidence.isExactSliceOf(
              fixtures.canonicalTranscripts[evidence.entryId]!,
            ),
            isTrue,
          );
        }
      }
      for (final conclusion in [
        fixtures.oneMomentConclusion,
        fixtures.threeMomentConclusion,
        fixtures.fiveMomentConclusion,
      ]) {
        for (final evidence in conclusion.evidence) {
          final transcript = fixtures.canonicalTranscripts[evidence.entryId]!;
          expect(
            transcript.substring(evidence.startUtf16, evidence.endUtf16),
            evidence.quote,
          );
        }
      }
    });

    test(
      'feature source has no production store, inference, or write access',
      () {
        final source = [
          File(
            'lib/features/onboarding_future_value/'
            'onboarding_future_value_fixtures.dart',
          ).readAsStringSync(),
          File(
            'lib/features/onboarding_future_value/future_preview_screen.dart',
          ).readAsStringSync(),
        ].join('\n');

        for (final forbidden in [
          'AppServices',
          'JournalStore',
          'PersonalKnowledgeGraphStore',
          'ExplainabilityHistoryStore',
          'Provider',
          'inference',
          'http.',
          'writeMap(',
          'writeBool(',
        ]) {
          expect(source, isNot(contains(forbidden)), reason: forbidden);
        }
      },
    );
  });

  group('future preview walkthrough', () {
    testWidgets(
      'navigates stages by controls and swipe with disclaimer visible',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _app(
            onEvent: (event) {
              events.add(event);
            },
          ),
        );
        await tester.pump();

        expect(find.text(OnboardingFutureValueCopy.disclaimer), findsOneWidget);
        expect(
          find.byKey(const Key('future_preview_one_quote')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('future_preview_next')));
        await tester.pumpAndSettle();
        expect(find.text(OnboardingFutureValueCopy.threeTitle), findsOneWidget);
        expect(find.text(OnboardingFutureValueCopy.disclaimer), findsOneWidget);

        await tester.fling(
          find.byKey(const Key('future_preview_page_view')),
          const Offset(-700, 0),
          1200,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('future_preview_graph')), findsOneWidget);
        expect(find.text(OnboardingFutureValueCopy.disclaimer), findsOneWidget);
        expect(
          events,
          containsAll(<String>[
            'futurePreviewSeen',
            'futurePreviewStage1',
            'futurePreviewStage3',
            'futurePreviewStage5',
          ]),
        );
      },
    );

    testWidgets('exposes evidence, alternatives, history, and graph nodes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await _goToStage(tester, 1);

      await _ensureVisible(
        tester,
        find.byKey(const Key('explainable_alternatives_button')),
      );
      await tester.tap(
        find.byKey(const Key('explainable_alternatives_button')),
      );
      await tester.pumpAndSettle();
      final alternativesSheet = find.byKey(
        const Key('explainable_alternatives_sheet'),
      );
      expect(alternativesSheet, findsOneWidget);
      await _dismissSheet(tester, alternativesSheet);

      final evidence = find.byKey(
        const ValueKey('explainable_evidence_onboarding-preview-entry-1_15'),
      );
      await _ensureVisible(tester, evidence);
      await tester.tap(evidence);
      await tester.pumpAndSettle();
      final evidenceSheet = find.byKey(
        const Key('future_preview_evidence_sheet'),
      );
      expect(evidenceSheet, findsOneWidget);
      await _dismissSheet(tester, evidenceSheet);

      await _goToStage(tester, 2);
      final graphNode = find.byKey(
        const Key('future_preview_graph_node_habit'),
      );
      await _ensureVisible(tester, graphNode);
      final node = _semanticsNode(
        tester,
        'Pause before replying, habit, 4 fictional evidence items',
      )!;
      _performCustomAction(tester, node, 'View fictional evidence');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('future_preview_node_evidence_sheet')),
        findsOneWidget,
      );
      await _dismissSheet(
        tester,
        find.byKey(const Key('future_preview_node_evidence_sheet')),
      );
      expect(Focus.of(tester.element(graphNode)).hasFocus, isTrue);

      await _ensureVisible(
        tester,
        find.byKey(const Key('explainable_history_button')),
      );
      await tester.tap(find.byKey(const Key('explainable_history_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('future_preview_history_sheet')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('honors reduced motion and supports skip/start callbacks', (
      tester,
    ) async {
      var exits = 0;
      var starts = 0;
      await tester.pumpWidget(
        _app(
          disableAnimations: true,
          onExit: () => exits++,
          onStart: () => starts++,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('future_preview_stage_chip_2')));
      await tester.pump();
      expect(find.byKey(const Key('future_preview_graph')), findsOneWidget);

      await tester.tap(find.byKey(const Key('future_preview_start')));
      await tester.pump();
      expect(starts, 1);

      await tester.tap(find.byKey(const Key('future_preview_skip')));
      await tester.pump();
      expect(exits, 1);
    });

    testWidgets('320x568 with large text has no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(textScale: 1.8));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await _goToStage(tester, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'supports 320 percent text and a short landscape without overflow',
      (tester) async {
        await tester.pumpWidget(_app(textScale: 3.2));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.text('Preview')),
          ).scale(10),
          32,
        );
        expect(tester.getSize(find.byType(AppBar)).height, greaterThan(64));
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byKey(const Key('future_preview_next'))),
          ).scale(10),
          32,
        );

        await tester.pumpWidget(
          _app(textScale: 3.2, size: const Size(568, 320)),
        );
        await tester.pump();
        await _goToStage(tester, 2);
        expect(tester.takeException(), isNull);
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.text('Preview')),
          ).scale(10),
          32,
        );
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byKey(const Key('future_preview_start'))),
          ).scale(10),
          32,
        );

        final nextSize = tester.getSize(
          find.byKey(const Key('future_preview_start')),
        );
        expect(nextSize.height, greaterThanOrEqualTo(48));
      },
    );

    testWidgets('accessible navigation disables swipe but keeps controls', (
      tester,
    ) async {
      await tester.pumpWidget(_app(accessibleNavigation: true));
      await tester.pump();

      await tester.fling(
        find.byKey(const Key('future_preview_page_view')),
        const Offset(-700, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('future_preview_one_quote')), findsOneWidget);

      await tester.tap(find.byKey(const Key('future_preview_next')));
      await tester.pump();
      expect(find.text(OnboardingFutureValueCopy.threeTitle), findsOneWidget);
    });
  });

  testWidgets('record card keeps microphone action before preview link', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordFirstRunScreenCard(
              onRecord: () {},
              recordButtonLabel: 'Record a moment',
              onFuturePreview: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
    expect(
      find.byKey(const Key('record_first_run_future_preview')),
      findsOneWidget,
    );
    final recordTop = tester.getTopLeft(
      find.byKey(const Key('capture_entry_record_cta')),
    );
    final previewTop = tester.getTopLeft(
      find.byKey(const Key('record_first_run_future_preview')),
    );
    expect(recordTop.dy, lessThan(previewTop.dy));
  });

  test(
    'route is V1-allowed and router includes onboarding/trial exemptions',
    () {
      expect(
        V1NavigationGuard.isAllowed(OnboardingFutureValueCopy.route),
        isTrue,
      );
      final source = File('lib/router/app_router.dart').readAsStringSync();
      expect(source, contains('path: OnboardingFutureValueCopy.route'));
      expect(source, contains('onboardingPaths'));
      expect(
        RegExp(
          r"onboardingPaths = \{[\s\S]*OnboardingFutureValueCopy\.route",
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r"TrialMode\.hideDeveloperSurfaces[\s\S]*"
          r"path != OnboardingFutureValueCopy\.route",
        ).hasMatch(source),
        isTrue,
      );
    },
  );

  test('consumer copy is explicit and avoids overclaims', () {
    const copy = [
      OnboardingFutureValueCopy.disclaimer,
      OnboardingFutureValueCopy.subtitle,
      OnboardingFutureValueCopy.oneBody,
      OnboardingFutureValueCopy.threeBody,
      OnboardingFutureValueCopy.fiveBody,
      OnboardingFutureValueCopy.finalExpectation,
    ];
    expect(OnboardingFutureValueCopy.disclaimer, contains('fictional'));
    expect(
      OnboardingFutureValueCopy.disclaimer,
      contains('none of your archive'),
    );
    for (final text in copy) {
      final lower = text.toLowerCase();
      for (final banned in [
        'therapy',
        'coaching',
        'pattern found',
        'guaranteed',
        'always',
      ]) {
        expect(lower, isNot(contains(banned)), reason: text);
      }
    }
  });
}

SemanticsNode? _semanticsNode(WidgetTester tester, String label) {
  SemanticsNode? result;
  bool visit(SemanticsNode node) {
    if (node.getSemanticsData().label == label) {
      result = node;
      return false;
    }
    node.visitChildren(visit);
    return result == null;
  }

  // The test binding owns the active semantics tree.
  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return result;
}

void _performCustomAction(
  WidgetTester tester,
  SemanticsNode node,
  String label,
) {
  final id = CustomSemanticsAction.getIdentifier(
    CustomSemanticsAction(label: label),
  );
  expect(node.getSemanticsData().customSemanticsActionIds, contains(id));
  // The test binding owns the active semantics tree.
  // ignore: deprecated_member_use
  tester.binding.pipelineOwner.semanticsOwner!.performAction(
    node.id,
    SemanticsAction.customAction,
    id,
  );
}
