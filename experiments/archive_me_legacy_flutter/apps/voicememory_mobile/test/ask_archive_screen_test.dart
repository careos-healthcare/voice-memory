import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/screens/ask_archive_screen.dart';

KeyMoment _moment(
  String id,
  DateTime date, {
  String title = 'Moment',
  String text = 'a moment',
  String? resultHint,
  List<String> tags = const [],
  String? nextCheck,
}) => KeyMoment(
  id: id,
  date: date,
  title: title,
  originalText: text,
  shortSummary: text,
  resultHint: resultHint,
  tags: tags,
  nextCheck: nextCheck,
);

Future<void> _pump(
  WidgetTester tester,
  List<KeyMoment> moments, {
  Future<bool> Function()? entitlementReader,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => AskArchiveScreen(
          loader: () async => moments,
          entitlementReader: entitlementReader ?? () async => true,
        ),
      ),
      GoRoute(
        path: '/moment-detail',
        builder: (context, state) =>
            Scaffold(body: Text('Detail ${(state.extra as KeyMoment).title}')),
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const Scaffold(body: Text('Record')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows title, subtitle, and suggested chips', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Ask my Archive'), findsOneWidget);
    expect(find.text('Search your saved moments.'), findsOneWidget);
    expect(find.text('When did this last show up?'), findsOneWidget);
    expect(find.text('What helped before?'), findsOneWidget);
    expect(find.text('Show moments about work'), findsOneWidget);
    expect(find.text('When did it feel lighter?'), findsOneWidget);
    expect(find.text('What changed this week?'), findsOneWidget);
    expect(find.text('Search moments'), findsOneWidget);
  });

  testWidgets('tapping a suggested chip shows results', (tester) async {
    await _pump(tester, [
      _moment(
        'a',
        DateTime.now(),
        title: 'Lighter day',
        resultHint: 'lighter',
        tags: const ['helped'],
      ),
    ]);

    await tester.tap(find.text('What helped before?'));
    await tester.pumpAndSettle();

    expect(find.text('Lighter day'), findsOneWidget);
    expect(find.text('Open moment'), findsOneWidget);
  });

  testWidgets('empty results show the empty state copy', (tester) async {
    await _pump(tester, [_moment('a', DateTime.now(), resultHint: 'heavier')]);

    await tester.tap(find.text('When did it feel lighter?'));
    await tester.pumpAndSettle();

    expect(
      find.text('Record a few moments and ArchiveMe will have more to find.'),
      findsOneWidget,
    );
  });

  testWidgets('typing a free-text query searches saved moments', (
    tester,
  ) async {
    await _pump(tester, [
      _moment(
        'a',
        DateTime.now(),
        title: 'Quiet worry',
        text: 'The worry came back when it got quiet.',
      ),
    ]);

    await tester.enterText(find.byType(TextField), 'worry');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Quiet worry'), findsOneWidget);
  });

  testWidgets('open moment navigates to detail', (tester) async {
    await _pump(tester, [
      _moment(
        'a',
        DateTime.now(),
        title: 'Open me',
        resultHint: 'lighter',
        tags: const ['helped'],
      ),
    ]);

    await tester.tap(find.text('What helped before?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open moment'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Open me'), findsOneWidget);
  });

  testWidgets('use this check navigates to record', (tester) async {
    await _pump(tester, [
      _moment(
        'a',
        DateTime.now(),
        title: 'Check moment',
        resultHint: 'lighter',
        tags: const ['helped'],
        nextCheck: 'What helped make it lighter?',
      ),
    ]);

    await tester.tap(find.text('What helped before?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this check'));
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsOneWidget);
  });
}
