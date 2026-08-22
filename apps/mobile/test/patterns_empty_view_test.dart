import 'package:archiveme_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  testWidgets(
    'patterns empty state shows archive four-state copy and record CTA',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing saved yet'), findsOneWidget);
      expect(find.text('Record a moment'), findsOneWidget);
      expect(find.text('Patterns'), findsNothing);
      expect(find.text('Changes'), findsNothing);
      expect(find.text('Next to watch'), findsNothing);
      expect(find.text('Type instead'), findsNothing);
      expect(
        find.byKey(const Key('archive_tab_record_moment_cta')),
        findsOneWidget,
      );
      expect(find.text('Current belief'), findsNothing);
      expect(find.text('Not enough evidence yet'), findsNothing);
      expect(find.text('Start your first week'), findsNothing);
      expect(find.textContaining('Step 0 of 7'), findsNothing);
      expect(find.textContaining('Save seven moments'), findsNothing);
      expect(find.text('Record one moment'), findsNothing);
      expect(find.text('Record first moment'), findsNothing);
      expect(find.textContaining('VoiceMemory'), findsNothing);
      _expectNoMindMapBannedCopy(_visibleTextOnScreen(tester));
    },
  );

  testWidgets('fillViewport scroll view renders without layout exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatternsEmptyView(fillViewport: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('primary CTA routes to Record tab', (tester) async {
    final router = GoRouter(
      initialLocation: '/patterns-empty',
      routes: [
        GoRoute(
          path: '/patterns-empty',
          builder: (context, state) =>
              const Scaffold(body: PatternsEmptyView()),
        ),
        GoRoute(
          path: '/record',
          builder: (context, state) => const Scaffold(body: Text('RECORD_TAB')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('archive_tab_record_moment_cta')));
    await tester.pumpAndSettle();

    expect(find.text('RECORD_TAB'), findsOneWidget);
  });

  testWidgets('patterns empty is readable on iPad width', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatternsEmptyView()),
      ),
    );
    await tester.pumpAndSettle();

    final body = tester.widget<Text>(find.textContaining('Nothing saved yet'));
    expect(body.style?.fontSize ?? 0, greaterThanOrEqualTo(14));
  });
}