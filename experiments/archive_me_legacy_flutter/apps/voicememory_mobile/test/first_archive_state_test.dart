import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:voicememory_mobile/features/archive_tab/archive_tab_four_state_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
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
  final tmp = await Directory.systemTemp.createTemp('vm_first_archive_');
  await AppServices.resetForTest(
    journalPath: '${tmp.path}/journal.json',
    prefsPath: '${tmp.path}/prefs.json',
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

void main() {
  setUp(() async {
    await _resetServices();
  });

  group('Copy split', () {
    test('zero-entry copy uses mind-map preview', () {
      expect(
        ConsumerUiCopy.patternsEmptyPageTitle,
        'Record a few real moments',
      );
      expect(ConsumerUiCopy.patternsEmptyCta, 'Record moment');
      expect(ConsumerUiCopy.patternsEmptyPageBody, contains('what repeats'));
    });

    test('one-entry copy confirms archive started without pattern claim', () {
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedTitle,
        VisibleArchiveProofCopy.patternsOneEntryTitle,
      );
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedBody,
        VisibleArchiveProofCopy.patternsOneEntryBody,
      );
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedCta,
        VisibleArchiveProofCopy.firstSavePrimaryCta,
      );
    });

    test('one saved entry is not intentional empty archive', () {
      expect(isIntentionalEmptyArchive([_entry()]), isFalse);
      expect(archiveEvidenceReflectionCount([_entry()]), 1);
    });
  });

  group('PatternsEmptyView — zero entries only', () {
    testWidgets('shows four-state empty copy and record CTA only', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
      );
      await tester.pump();

      expect(find.text(ArchiveTabFourStateCopy.emptyBody), findsOneWidget);
      expect(find.text('Record a moment'), findsOneWidget);
      expect(find.text('Patterns'), findsNothing);
      expect(find.text('Changes'), findsNothing);
      expect(find.text('Next to watch'), findsNothing);
      expect(find.text('Type instead'), findsNothing);
      expect(find.text('Current belief'), findsNothing);
      expect(find.text('Not enough evidence yet'), findsNothing);
      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
        findsNothing,
      );
    });

    testWidgets('shows exactly one record moment CTA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_tab_record_moment_cta')),
        findsOneWidget,
      );
      expect(find.text('Record a moment'), findsOneWidget);
      expect(find.text('Record moment'), findsNothing);
    });

    testWidgets('does not show one-entry saved copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
        ),
      );
      await tester.pump();

      expect(find.text('Add one more moment'), findsNothing);
      expect(
        find.text('Your archive has one piece of evidence.'),
        findsNothing,
      );
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
        find.text(VisibleArchiveProofCopy.patternsOneEntryReassurance),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsOneEntryCta),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.patternsEmptyPreviewBadge),
        findsNothing,
      );
      expect(find.text('Evidence'), findsNothing);
      expect(find.text('Pattern your archive is watching'), findsNothing);
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

  group(
    'ArchiveBeliefScreen — zero entries',
    () {
      testWidgets('shows four-state empty copy without archive clutter', (
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

        expect(find.text(ArchiveTabFourStateCopy.emptyBody), findsOneWidget);
        expect(find.text('Record a moment'), findsOneWidget);
        expect(find.text('Patterns'), findsNothing);
        expect(find.text('Changes'), findsNothing);
        expect(find.text('Type instead'), findsNothing);
        expect(find.text('Current belief'), findsNothing);
        expect(find.text('Not enough evidence yet'), findsNothing);
        expect(
          find.byKey(const Key('archive_home_summary_card')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('archive_tab_entry_state_empty')),
          findsOneWidget,
        );
        for (final text
            in tester
                .widgetList<Text>(find.byType(Text))
                .map((w) => w.data ?? '')) {
          final lower = text.toLowerCase();
          for (final phrase in const [
            'therapy',
            'diagnosis',
            'brain mapping',
            'mental health score',
            'archiveme knows',
          ]) {
            expect(
              lower,
              isNot(contains(phrase)),
              reason: 'banned "$phrase" in "$text"',
            );
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

          final formingTitle = find.text(
            VisibleArchiveProofCopy.patternsMindMapFormingTitle,
          );
          final emptyTitle = find.text(
            VisibleArchiveProofCopy.patternsMindMapEmptyTitle,
          );
          if (formingTitle.evaluate().isNotEmpty) {
            expect(
              find.textContaining(
                VisibleArchiveProofCopy.patternsMindMapFormingBody,
              ),
              findsOneWidget,
            );
            expect(
              find.text(
                VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta,
              ),
              findsOneWidget,
            );
            expect(
              find.text(VisibleArchiveProofCopy.typeInsteadCta),
              findsOneWidget,
            );
          } else if (emptyTitle.evaluate().isNotEmpty) {
            expect(
              find.text('Record moment').evaluate().isNotEmpty ||
                  find
                      .text(
                        VisibleArchiveProofCopy
                            .patternsMindMapFormingPrimaryCta,
                      )
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
          find.textContaining(
            VisibleArchiveProofCopy.patternsMindMapFormingBody,
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
    },
    skip: 'Superseded by the focused V1 Archive layout',
  );

  group(
    'ArchiveBeliefScreen — one entry after first save',
    () {
      testWidgets('shows one-entry four-state copy without CTAs', (
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

        expect(find.text(ArchiveTabFourStateCopy.oneBody), findsOneWidget);
        expect(
          find.byKey(const Key('archive_tab_entry_state_one')),
          findsOneWidget,
        );
        expect(find.text('Record a moment'), findsNothing);
        expect(find.text('View evidence'), findsNothing);
        expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
        expect(
          find.byKey(const Key('archive_home_summary_card')),
          findsNothing,
        );
      });

      testWidgets('short transcript still shows one-entry four-state copy', (
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

        expect(find.text(ArchiveTabFourStateCopy.oneBody), findsOneWidget);
        expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
      });
    },
    skip: 'Superseded by the focused V1 Archive layout',
  );

  group(
    'ArchiveBeliefScreen — two entries four-state',
    () {
      testWidgets('grounded repeat shows related pattern copy and view evidence', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(
            _entry(
              id: 'a',
              transcript:
                  'I had no capacity but I said yes again to the extra meeting today.',
            ),
          );
          await AppServices.instance.journalStore.save(
            _entry(
              id: 'b',
              transcript:
                  'Same thing — said yes when I had no capacity for one more thing.',
            ),
          );
        });

        await tester.binding.setSurfaceSize(const Size(390, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: ArchiveBeliefScreen(key: UniqueKey()),
          ),
        );
        await tester.pump();
        await _pumpUntil(
          tester,
          find.byKey(const Key('archive_tab_entry_state_twoRelated')),
        );

        final model = ArchiveTabFourStateEngine.build(
          entries: await AppServices.instance.journal.loadAll(),
        );
        expect(model!.state, ArchiveTabFourState.twoRelated);
        expect(find.text(model.body), findsOneWidget);
        expect(find.textContaining('This may connect to:'), findsOneWidget);
        expect(find.textContaining('What changed:'), findsOneWidget);
        expect(
          find.byKey(const Key('archive_tab_view_evidence_cta')),
          findsOneWidget,
        );
        expect(find.text('View evidence'), findsOneWidget);
        expect(
          find.byKey(const Key('archive_first_comparison_card')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('early_first_signal_card_twoEntryFirstSignal')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('archive_home_summary_card')),
          findsNothing,
        );
      });

      testWidgets('unrelated two entries show no-pattern copy without CTAs', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await AppServices.instance.journalStore.save(
            _entry(
              id: 'a',
              transcript: 'A quiet moment about lunch with a friend today.',
            ),
          );
          await AppServices.instance.journalStore.save(
            _entry(
              id: 'b',
              transcript:
                  'Another unrelated note about errands this afternoon.',
            ),
          );
        });

        await tester.binding.setSurfaceSize(const Size(390, 2200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: ArchiveBeliefScreen(key: UniqueKey()),
          ),
        );
        await tester.pump();
        await _pumpUntil(
          tester,
          find.byKey(const Key('archive_tab_entry_state_twoUnrelated')),
        );

        expect(
          find.text(ArchiveTabFourStateCopy.twoUnrelatedBody),
          findsOneWidget,
        );
        expect(find.text('View evidence'), findsNothing);
        expect(find.text('Record a moment'), findsNothing);
        expect(
          find.text(EarlyFirstSignalCopy.twoEntryNoPatternTitle),
          findsNothing,
        );
        expect(
          find.byKey(const Key('archive_home_summary_card')),
          findsNothing,
        );
      });
    },
    skip: 'Superseded by the focused V1 Archive layout',
  );

  group('App restart persistence', () {
    test('saved entry persists across journal store reopen', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_restart_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journalPath = '${tempDir.path}/entries.json';

      final store = await JournalStore.open(journalPath, encryptAtRest: false);
      await store.save(_entry(id: 'persist1'));

      final reopened = await JournalStore.open(
        journalPath,
        encryptAtRest: false,
      );
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
