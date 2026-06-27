import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_first_archive_view.dart';

const _mindMapBannedPhrases = [
  'therapy',
  'diagnosis',
  'brain mapping',
  'mental health score',
  'archiveme knows',
  "today's exercise",
  'archive exercise',
];

List<String> _visibleTextOnScreen(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final data = widget.data;
    if (data != null && data.isNotEmpty) {
      texts.add(data);
    }
  }
  return texts;
}

void _expectNoMindMapBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final phrase in _mindMapBannedPhrases) {
      expect(
        lower,
        isNot(contains(phrase)),
        reason: 'must not contain "$phrase" in "$text"',
      );
    }
  }
}

void main() {
  testWidgets('patterns empty state shows mind-map copy and one primary CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
      findsOneWidget,
    );
    expect(
      find.textContaining('Save a few real moments'),
      findsOneWidget,
    );
    expect(find.text('Patterns'), findsOneWidget);
    expect(find.text('Changes'), findsOneWidget);
    expect(find.text('Next to watch'), findsOneWidget);
    expect(
      find.byKey(const Key('patterns_mind_map_empty_primary_cta')),
      findsOneWidget,
    );
    expect(find.text('Save your first moment'), findsOneWidget);
    expect(find.text('Type instead'), findsOneWidget);
    expect(find.text('Current belief'), findsNothing);
    expect(find.text('Not enough evidence yet'), findsNothing);
    expect(find.text('Start your first week'), findsNothing);
    expect(find.textContaining('Step 0 of 7'), findsNothing);
    expect(find.textContaining('Save seven moments'), findsNothing);
    expect(find.text('Record one moment'), findsNothing);
    expect(find.text('Record first moment'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
    _expectNoMindMapBannedCopy(_visibleTextOnScreen(tester));
  });

  testWidgets('fillViewport scroll view renders without layout exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PatternsEmptyView(fillViewport: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
      findsOneWidget,
    );
  });

  testWidgets('primary CTA routes to Record tab', (tester) async {
    final router = GoRouter(
      initialLocation: '/patterns-empty',
      routes: [
        GoRoute(
          path: '/patterns-empty',
          builder: (context, state) =>
              const Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
        GoRoute(
          path: '/record',
          builder: (context, state) =>
              const Scaffold(body: Text('RECORD_TAB')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('patterns_mind_map_empty_primary_cta')));
    await tester.pumpAndSettle();

    expect(find.text('RECORD_TAB'), findsOneWidget);
  });

  testWidgets('patterns first-archive view shows one-entry saved copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PatternsFirstArchiveView(
            fillViewport: false,
            savedEntryId: 'e1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.patternsFirstEntrySavedBody),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.patternsFirstEntrySavedCta),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
    expect(find.text(ConsumerUiCopy.patternsEmptyCta), findsNothing);
  });

  testWidgets('patterns empty is readable on iPad width', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle),
    );
    expect(title.style?.fontSize ?? 0, greaterThanOrEqualTo(26));
  });
}
