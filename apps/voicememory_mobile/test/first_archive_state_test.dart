import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/archive_belief_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_first_archive_view.dart';

JournalEntry _entry({String id = 'e1', String? transcript}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript:
        transcript ??
        'A long enough transcript to count as a saved reflection.',
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

Future<void> _resetServices() async {
  await AppServices.resetForTest(
    journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
    prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
    skipRevenueCat: true,
  );
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  group('Copy split', () {
    test('zero-entry copy stays preview-style', () {
      expect(
        ConsumerUiCopy.patternsEmptyPageTitle,
        'What ArchiveMe will show over time',
      );
      expect(ConsumerUiCopy.patternsEmptyCta, 'Record one moment');
    });

    test('one-entry copy confirms save and second entry value', () {
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedTitle,
        'Your archive has one piece of evidence.',
      );
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedBody,
        'Add one more moment and ArchiveMe can start comparing your own words.',
      );
      expect(ConsumerUiCopy.patternsFirstEntrySavedCta, 'Add one more moment');
    });

    test('one saved entry is not intentional empty archive', () {
      expect(isIntentionalEmptyArchive([_entry()]), isFalse);
      expect(archiveEvidenceReflectionCount([_entry()]), 1);
    });
  });

  group('PatternsEmptyView — zero entries only', () {
    testWidgets('shows zero-entry title and CTA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
      );
      await tester.pump();

      expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsOneWidget);
      expect(find.text(ConsumerUiCopy.patternsEmptyCta), findsOneWidget);
      expect(find.text('Record one moment'), findsOneWidget);
      expect(find.text('Record first moment'), findsNothing);
      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
        findsNothing,
      );
    });

    testWidgets('does not show one-entry saved copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
      );
      await tester.pump();

      expect(find.text('Add one more moment'), findsNothing);
      expect(find.text('Your archive has one piece of evidence.'), findsNothing);
    });
  });

  group('PatternsFirstArchiveView — one entry', () {
    testWidgets('shows first-entry saved state without zero-entry copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PatternsFirstArchiveView(savedEntryId: 'e1')),
        ),
      );
      await tester.pump();

      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
        findsOneWidget,
      );
      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedBody),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsOneEntryEvidenceRow),
        findsOneWidget,
      );
      expect(find.text(VisibleArchiveProofCopy.patternsEmptyPreviewBadge), findsOneWidget);
      expect(find.text('Add one more moment'), findsOneWidget);
      expect(find.text('Record first moment'), findsNothing);
      expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
      expect(find.text('Record one moment'), findsNothing);
    });

    testWidgets('view saved entry opens entry detail route', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: PatternsFirstArchiveView(savedEntryId: 'e1')),
          ),
          GoRoute(
            path: '/entry/:id',
            builder: (context, state) =>
                Scaffold(body: Text('ENTRY:${state.pathParameters['id']}')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('patterns_first_archive_view_saved_entry')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ENTRY:e1'), findsOneWidget);
    });

    testWidgets('add another moment routes to record tab', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: PatternsFirstArchiveView(savedEntryId: 'e1'),
            ),
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

      await tester.tap(
        find.byKey(const Key('patterns_first_archive_record_another')),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECORD_TAB'), findsOneWidget);
    });
  });

  group('ArchiveBeliefScreen — one entry after first save', () {
    testWidgets('shows first-saved state not zero-entry copy', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry());
      });

      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveBeliefScreen(key: UniqueKey()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
        findsOneWidget,
      );
      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedBody),
        findsOneWidget,
      );
      expect(find.text('Add one more moment'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
      expect(find.text('Record one moment'), findsNothing);
    });

    testWidgets('short transcript still shows first-saved state', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _entry(transcript: 'too short'),
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveBeliefScreen(key: UniqueKey()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(VisibleArchiveProofCopy.patternsOneEntryTitle),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
    });
  });

  group('Layout and brand safety', () {
    const surfaces = <MapEntry<String, Size>>[
      MapEntry('iphone_17_pro', Size(402, 874)),
      MapEntry('small_android', Size(360, 640)),
    ];

    for (final surface in surfaces) {
      testWidgets('no overflow on ${surface.key}', (tester) async {
        await tester.binding.setSurfaceSize(surface.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PatternsFirstArchiveView(savedEntryId: 'e1'),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('VoiceMemory'), findsNothing);
        expect(find.textContaining('ChatGPT'), findsNothing);
        expect(find.textContaining('OpenAI'), findsNothing);
      });
    }
  });
}
