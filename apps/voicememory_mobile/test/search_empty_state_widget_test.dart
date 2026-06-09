import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/router/onboarding_gate.dart';
import 'package:voicememory_mobile/screens/search_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/empty_states/search_empty_state.dart';

JournalEntry _eligibleEntry(String id) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    transcript:
        'This is a long enough transcript to count as archive evidence for search.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

Widget _searchTestApp({required Widget child, String initialLocation = '/'}) {
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        GoRoute(
          path: '/record',
          builder: (_, _) => const Scaffold(body: Text('record')),
        ),
        GoRoute(
          path: '/quick-capture',
          builder: (_, _) => const Scaffold(body: Text('quick-capture')),
        ),
      ],
    ),
  );
}

bool _focusNodeHasFocus(WidgetTester tester) {
  final element = tester.element(find.byType(TextField));
  return Focus.maybeOf(element)?.hasFocus ?? false;
}

void main() {
  group('SearchEmptyState widget', () {
    setUp(() async {
      // SearchEmptyState embeds StartHereLoader, which reads AppServices in
      // initState — initialize it so the widget can build under test.
      final tempDir = Directory.systemTemp.createTempSync('vm_search_empty_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
    });

    testWidgets('renders title, bullets, examples, and CTAs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SearchEmptyState()),
        ),
      );

      expect(find.text('Nothing to search yet'), findsOneWidget);
      expect(find.text("You'll be able to search for:"), findsOneWidget);
      expect(find.text("beliefs you've repeated"), findsOneWidget);
      expect(find.text('people, places, and events'), findsOneWidget);
      expect(
        find.text('Months from now you might search for:'),
        findsOneWidget,
      );
      expect(find.text('"confidence"'), findsOneWidget);
      expect(find.text('"burnout"'), findsOneWidget);
      expect(find.text('"starting a business"'), findsOneWidget);
      expect(find.text('"I\'m not ready"'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.startRecording), findsOneWidget);
      expect(find.text('Type Instead'), findsOneWidget);
      expect(find.byType(SearchEmptyState), findsOneWidget);
      expect(find.byType(IntentionalEmptyArchiveView), findsNothing);
    });
  });

  group('SearchScreen', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_search_test_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      await AppServices.instance.prefs.setOnboardingCompleted(true);
      onboardingGate.markComplete();
    });

    testWidgets('does not autofocus search field when screen opens', (tester) async {
      await tester.pumpWidget(_searchTestApp(child: const SearchScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isFalse);
      expect(_focusNodeHasFocus(tester), isFalse);
    });

    testWidgets('shows SearchEmptyState when there are no recordings',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_searchTestApp(child: const SearchScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SearchEmptyState), findsOneWidget);
      expect(find.text('Nothing to search yet'), findsOneWidget);
      expect(find.byType(IntentionalEmptyArchiveView), findsNothing);
    });

    testWidgets('uses idle slot when recordings exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: buildSearchEmptyQueryChild(
              entries: [_eligibleEntry('e1')],
              idleWhenSearchable: const Text('SEARCH_IDLE_SLOT'),
            ),
          ),
        ),
      );

      expect(find.text('SEARCH_IDLE_SLOT'), findsOneWidget);
      expect(find.byType(SearchEmptyState), findsNothing);
    });
  });
}
