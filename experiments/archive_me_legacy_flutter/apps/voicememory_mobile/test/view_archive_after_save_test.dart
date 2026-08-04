import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/router/developer_route_guard.dart';
import 'package:voicememory_mobile/screens/archive_belief_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_first_archive_view.dart';

JournalEntry _entry({String id = 'e1'}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: 'A long enough transcript to count as a saved reflection.',
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
  final dir = Directory.systemTemp.createTempSync('vm_view_archive_');
  await AppServices.resetForTest(
    journalPath: '${dir.path}/journal.json',
    prefsPath: '${dir.path}/prefs.json',
    skipRevenueCat: true,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 50,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

Future<void> _pumpEmptyPatterns(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ArchiveBeliefScreen(key: UniqueKey()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  group('View archive routing', () {
    test('legacy journal path redirects to patterns tab in production', () {
      expect(
        DeveloperRouteGuard.redirectFor('/journal'),
        DeveloperRouteGuard.patternsHome,
      );
      expect(DeveloperRouteGuard.patternsHome, '/archive-belief');
    });

    testWidgets(
      'first-save View archive navigates to patterns tab not record',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/record',
          routes: [
            GoRoute(
              path: '/record',
              builder: (context, state) => Scaffold(
                body: FirstSaveEvidenceCard(
                  onViewArchive: () => context.go('/archive-belief'),
                  onRecordAnother: () {},
                  onDoneForToday: () {},
                ),
              ),
            ),
            GoRoute(
              path: '/archive-belief',
              builder: (context, state) =>
                  const Scaffold(body: Text('PATTERNS_TAB_MARKER')),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('first_save_view_archive_cta')));
        await tester.pumpAndSettle();

        expect(find.text('PATTERNS_TAB_MARKER'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/archive-belief',
        );
      },
    );

    testWidgets('archive screen shows focused intelligence after first save', (
      tester,
    ) async {
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

      expect(find.text('What changed?'), findsOneWidget);
      expect(find.text('Why ArchiveMe thinks that'), findsOneWidget);
      expect(find.text('Supporting moments'), findsOneWidget);
      expect(find.text('What to record or test next'), findsOneWidget);
      expect(
        find.textContaining('not enough reliable history'),
        findsOneWidget,
      );
      expect(find.byType(PatternsFirstArchiveView), findsNothing);
      expect(find.text('Record first moment'), findsNothing);
      expect(find.text('Record one moment'), findsNothing);
      expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
    });
  });

  group('Patterns tab empty vs first-save state', () {
    testWidgets('zero entries shows mind-map empty state only', (tester) async {
      await _pumpEmptyPatterns(tester);
      await _pumpUntil(
        tester,
        find.textContaining(ArchiveTabFourStateCopy.emptyBody),
      );

      expect(
        find.textContaining(ArchiveTabFourStateCopy.emptyBody),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveTabFourStateCopy.recordMomentCta),
        findsOneWidget,
      );
      expect(find.text('Current belief'), findsNothing);
      expect(find.text('Start your first week'), findsNothing);
      expect(find.text('Record first moment'), findsNothing);
      expect(find.byType(PatternsFirstArchiveView), findsNothing);
    });

    test('one eligible entry is not treated as intentional empty archive', () {
      expect(isIntentionalEmptyArchive([_entry()]), isFalse);
      expect(archiveEvidenceReflectionCount([_entry()]), 1);
    });

    testWidgets('first archive widget shows desired one-entry copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PatternsFirstArchiveView(savedEntryId: 'e1'),
        ),
      );
      await tester.pump();

      expect(
        find.text(VisibleArchiveProofCopy.patternsOneEntryTitle),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsOneEntryBody),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsOneEntryReassurance),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePrimaryCta),
        findsOneWidget,
      );
      expect(find.text('Record first moment'), findsNothing);
      expect(find.text('Record one moment'), findsNothing);
      expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
    });

    test('journal drift is visible to patterns tab after first save', () async {
      expect(
        peekJournalEntriesSync(AppServices.instance.journalStore).length,
        0,
      );
      await AppServices.instance.journalStore.save(_entry());
      expect(
        archiveEvidenceReflectionCount(
          peekJournalEntriesSync(AppServices.instance.journalStore),
        ),
        1,
      );
    });
  });

  group('Layout and brand safety', () {
    const surfaces = <MapEntry<String, Size>>[
      MapEntry('iphone_17_pro', Size(402, 874)),
      MapEntry('small_android', Size(360, 640)),
    ];

    for (final surface in surfaces) {
      testWidgets('no overflow on ${surface.key} for first-archive view', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(surface.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
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
