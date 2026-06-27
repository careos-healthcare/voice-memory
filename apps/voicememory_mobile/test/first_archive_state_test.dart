import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/archive_belief_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_beliefs_presenter.dart';
import 'package:voicememory_mobile/features/archive_growth/archive_growth_service.dart';
import 'package:voicememory_mobile/features/discover/discover_local.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_mind_map_forming_card.dart';
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
    test('zero-entry copy uses mind-map preview', () {
      expect(
        ConsumerUiCopy.patternsEmptyPageTitle,
        'Your mind map will appear here',
      );
      expect(ConsumerUiCopy.patternsEmptyCta, 'Save your first moment');
      expect(
        ConsumerUiCopy.patternsEmptyPageBody,
        contains('Save a few real moments'),
      );
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
    testWidgets('shows mind-map empty title, preview rows, and CTAs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
      );
      await tester.pump();

      expect(
        find.text('Your mind map will appear here'),
        findsOneWidget,
      );
      expect(find.textContaining('Save a few real moments'), findsOneWidget);
      expect(find.text('Patterns'), findsOneWidget);
      expect(find.text('Changes'), findsOneWidget);
      expect(find.text('Next to watch'), findsOneWidget);
      expect(find.text('Save your first moment'), findsOneWidget);
      expect(find.text('Type instead'), findsOneWidget);
      expect(find.text('Current belief'), findsNothing);
      expect(find.text('Not enough evidence yet'), findsNothing);
      expect(find.text('Start your first week'), findsNothing);
      expect(find.textContaining('Step 0 of 7'), findsNothing);
      expect(find.textContaining('Save seven moments'), findsNothing);
      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
        findsNothing,
      );
    });

    testWidgets('shows exactly one primary save CTA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('patterns_mind_map_empty_primary_cta')),
        findsOneWidget,
      );
      expect(find.text('Save your first moment'), findsOneWidget);
      expect(find.text('Record one moment'), findsNothing);
      expect(find.text('Record first moment'), findsNothing);
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

  group('ArchiveBeliefScreen — zero entries', () {
    testWidgets('shows mind-map empty state without archive home clutter', (
      tester,
    ) async {
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
        find.text('Your mind map will appear here'),
        findsOneWidget,
      );
      expect(find.textContaining('Save a few real moments'), findsOneWidget);
      expect(find.text('Save your first moment'), findsOneWidget);
      expect(find.text('Type instead'), findsOneWidget);
      expect(find.text('Current belief'), findsNothing);
      expect(find.text('Not enough evidence yet'), findsNothing);
      expect(find.text('Start your first week'), findsNothing);
      expect(find.textContaining('Step 0 of 7'), findsNothing);
      expect(find.textContaining('Save seven moments'), findsNothing);
      expect(find.text(VisibleArchiveProofCopy.archiveHomeEmptyTitle), findsNothing);
      expect(find.byKey(const Key('archive_home_summary_card')), findsNothing);
      expect(find.textContaining('archive exercise'), findsNothing);
      expect(find.text("Today's exercise"), findsNothing);
      for (final text in tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '')) {
        final lower = text.toLowerCase();
        for (final phrase in const [
          'therapy',
          'diagnosis',
          'brain mapping',
          'mental health score',
          'archiveme knows',
        ]) {
          expect(lower, isNot(contains(phrase)), reason: 'banned "$phrase" in "$text"');
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'three-entry patterns dashboard shows forming fallback without crash',
      (tester) async {
        await tester.runAsync(() async {
          const themes = ['work', 'health', 'family'];
          for (var i = 0; i < 3; i++) {
            await AppServices.instance.journalStore.save(
              JournalEntry(
                id: 'eligible_$i',
                createdAt: DateTime(2026, 6, 12, 10 + i),
                transcript:
                    'Eligible reflection $i with enough transcript length for evidence.',
                durationSeconds: 30,
                reflection: Reflection(
                  mood: 'thoughtful',
                  emotionalIntensity: 2,
                  recurringThemes: [themes[i]],
                  exactLanguagePattern: 'pattern',
                  concreteObservation: 'Observation $i without shared theme.',
                  repeatedSignal: 'signal',
                ),
              ),
            );
          }
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
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(seconds: 2));
        });

        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        }

        expect(find.text('Current belief'), findsNothing);

        final formingTitle =
            find.text(VisibleArchiveProofCopy.patternsMindMapFormingTitle);
        final emptyTitle =
            find.text(VisibleArchiveProofCopy.patternsMindMapEmptyTitle);
        if (formingTitle.evaluate().isNotEmpty) {
          expect(
            find.textContaining(
              'ArchiveMe needs a little more usable evidence',
            ),
            findsOneWidget,
          );
          expect(
            find.text(VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta),
            findsOneWidget,
          );
          expect(
            find.text(VisibleArchiveProofCopy.typeInsteadCta),
            findsOneWidget,
          );
        } else if (emptyTitle.evaluate().isNotEmpty) {
          expect(
            find.text('Save your first moment').evaluate().isNotEmpty ||
                find.text(VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta)
                    .evaluate()
                    .isNotEmpty,
            isTrue,
          );
        }
      },
    );

    testWidgets('PatternsMindMapFormingCard shows mind-map forming copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PatternsMindMapFormingCard()),
        ),
      );
      await tester.pump();

      expect(
        find.text(VisibleArchiveProofCopy.patternsMindMapFormingTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining('ArchiveMe needs a little more usable evidence'),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta),
        findsOneWidget,
      );
      expect(find.text(VisibleArchiveProofCopy.typeInsteadCta), findsOneWidget);
    });

    test(
      'three distinct themes produce no strongest belief card for Patterns',
      () async {
        const themes = ['work', 'health', 'family'];
        for (var i = 0; i < 3; i++) {
          await AppServices.instance.journalStore.save(
            JournalEntry(
              id: 'eligible_$i',
              createdAt: DateTime(2026, 6, 12, 10 + i),
              transcript:
                  'Eligible reflection $i with enough transcript length for evidence.',
              durationSeconds: 30,
              reflection: Reflection(
                mood: 'thoughtful',
                emotionalIntensity: 2,
                recurringThemes: [themes[i]],
                exactLanguagePattern: 'pattern',
                concreteObservation: 'Observation $i without shared theme.',
                repeatedSignal: 'signal',
              ),
            ),
          );
        }
        final entries = await AppServices.instance.journal.loadAll();
        final feed = DiscoverLocalEngine.build(entries: entries);
        final growth = await ArchiveGrowthService.load();
        final beliefs = ArchiveBeliefsPresenter.build(
          entries: entries,
          archiveV1: growth.archiveV1,
          discoverFeed: feed,
        );
        final all = [
          ...beliefs.current,
          ...beliefs.homeBeliefs,
          ...beliefs.emerging,
          ...beliefs.changing,
          ...beliefs.hiddenPatterns,
        ];
        expect(all, isEmpty);
      },
    );
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
        find.text(VisibleArchiveProofCopy.archiveHomeOneTitle),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.archiveHomeOneBody),
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
          _entry(transcript: 'Short but still enough transcript chars.'),
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
        find.text(VisibleArchiveProofCopy.archiveHomeOneTitle),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
    });

    testWidgets('More archive tools expands on Patterns tab', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry());
      });

      await tester.binding.setSurfaceSize(const Size(402, 1800));
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
        find.text(ArchiveHomePriorityCopy.moreArchiveToolsTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('more_archive_tools_expanded_content')),
        findsNothing,
      );

      await tester.tap(find.text(ArchiveHomePriorityCopy.moreArchiveToolsTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const Key('more_archive_tools_expanded_content')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('more_archive_tools_toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const Key('more_archive_tools_expanded_content')),
        findsNothing,
      );
    });
  });

  group('App restart persistence', () {
    test('saved entry persists across journal store reopen', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_restart_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journalPath = '${tempDir.path}/entries.json';

      final store = await JournalStore.open(journalPath, encryptAtRest: false);
      await store.save(_entry(id: 'persist1'));

      final reopened = await JournalStore.open(journalPath, encryptAtRest: false);
      final entries = await reopened.loadAll();

      expect(entries.length, 1);
      expect(entries.first.id, 'persist1');
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
