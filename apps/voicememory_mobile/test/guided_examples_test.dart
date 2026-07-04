import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/onboarding/guided_examples_copy.dart';
import 'package:voicememory_mobile/features/onboarding/guided_examples_model.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/quick_text_capture_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/guided_examples_card.dart';
import 'package:voicememory_mobile/widgets/record/navigate_to_capture_mode.dart';
import 'package:voicememory_mobile/widgets/record/record_capture_modes_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
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

List<JournalEntry> _threeRelatedRepeatEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    VisualAuditOverrides.setRecordPresentation(null);
  });

  group('GuidedExamplesCopy', () {
    test('spec copy is stable', () {
      expect(GuidedExamplesCopy.title, 'Examples you can use as a guide');
      expect(GuidedExamplesCopy.subtitle, 'Use the style, not the exact words.');
      expect(GuidedExamplesCopy.useStyleCta, 'Use this style');
      expect(GuidedExamplesCatalog.examples, hasLength(5));
      expect(
        GuidedExamplesCatalog.examples.first.text,
        'I agreed before checking if I had time.',
      );
    });

    test('style helper references example without becoming transcript', () {
      const example = 'I paused before replying.';
      final helper = GuidedExamplesCopy.styleHelper(example);
      expect(helper, contains(GuidedExamplesCopy.subtitle));
      expect(helper, contains(example));
      expect(helper, isNot(startsWith(example)));
    });

    test('no therapy advice or coaching language', () {
      final joined = [
        GuidedExamplesCopy.title,
        GuidedExamplesCopy.subtitle,
        GuidedExamplesCopy.useStyleCta,
        ...GuidedExamplesCatalog.examples.map((e) => e.text),
      ].join(' ').toLowerCase();

      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('try this')));
      expect(joined, isNot(contains('therapy')));
      expect(joined, isNot(contains('diagnosis')));
      expect(joined, isNot(contains('revenuecat')));
      expect(joined, isNot(contains('restore purchases')));
      expect(ProofSurfaceAdviceGuard.passes(joined), isTrue);
    });
  });

  group('GuidedExamplesGates', () {
    test('shows for zero and one entry', () {
      for (final count in [0, 1]) {
        expect(
          GuidedExamplesGates.shouldShow(
            loaded: true,
            entryCount: count,
            isReady: true,
            isPostSave: false,
          ),
          isTrue,
        );
      }
    });

    test('hides after comparison seed', () {
      expect(
        GuidedExamplesGates.shouldShow(
          loaded: true,
          entryCount: 2,
          isReady: true,
          isPostSave: false,
        ),
        isFalse,
      );
    });

    test('hides while post-save', () {
      expect(
        GuidedExamplesGates.shouldShow(
          loaded: true,
          entryCount: 0,
          isReady: true,
          isPostSave: true,
        ),
        isFalse,
      );
    });
  });

  group('GuidedExamplesCard', () {
    testWidgets('renders all examples with use-style actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: GuidedExamplesCard(onUseStyle: (_) {}),
          ),
        ),
      );

      expect(find.byKey(const Key('guided_examples_card')), findsOneWidget);
      expect(find.text(GuidedExamplesCopy.title), findsOneWidget);
      expect(find.text(GuidedExamplesCopy.subtitle), findsOneWidget);
      for (final example in GuidedExamplesCatalog.examples) {
        expect(
          find.byKey(Key('guided_examples_text_${example.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('guided_examples_use_style_${example.id}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('use-style invokes callback without saving', (tester) async {
      GuidedExample? tapped;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: GuidedExamplesCard(
              onUseStyle: (example) {
                tapped = example;
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('guided_examples_use_style_agreed_before_checking'),
        ),
      );
      await tester.pump();

      expect(tapped?.id, 'agreed_before_checking');
      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, isEmpty);
    });
  });

  group('navigateToGuidedExampleStyle', () {
    testWidgets('opens typed capture with helper only', (tester) async {
      const example = GuidedExample(
        id: 'paused_before_replying',
        text: 'I paused before replying.',
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    unawaited(
                      navigateToGuidedExampleStyle(context, example: example),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/quick-capture',
            builder: (context, state) {
              final extra = state.extra! as Map<String, Object?>;
              return QuickTextCaptureScreen(
                helperText: extra['helper'] as String?,
                captureModeId: extra['captureModeId'] as String?,
                showGuidedExamples: extra['showGuidedExamples'] == true,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('quick_text_capture_field')), findsOneWidget);
      expect(
        find.byKey(const Key('quick_text_capture_mode_helper')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Example style: "I paused before replying."'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('quick_text_capture_field')))
            .controller!
            .text,
        isEmpty,
      );

      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, isEmpty);
    });
  });

  group('QuickTextCaptureScreen guided examples', () {
    Future<void> pumpCapture(WidgetTester tester, Widget child) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: child,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('capture-mode sheet shows compact examples for early users', (
      tester,
    ) async {
      const mode = RecordCaptureMode(
        id: RecordCaptureModeId.somethingHappened,
        label: RecordCaptureModeCopy.somethingHappenedLabel,
        helper: RecordCaptureModeCopy.somethingHappenedHelper,
        prompt: RecordCaptureModeCopy.somethingHappenedPrompt,
      );

      await pumpCapture(
        tester,
        QuickTextCaptureScreen(
          promptHint: mode.prompt,
          helperText: mode.helper,
          captureModeId: mode.analyticsId,
        ),
      );

      expect(find.byKey(const Key('guided_examples_capture_panel')), findsOneWidget);
      expect(
        find.byKey(const Key('guided_examples_capture_text_agreed_before_checking')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('guided_examples_capture_text_pressure_answer_quickly')),
        findsNothing,
      );
    });

    testWidgets('use-style updates helper without prefilling transcript', (
      tester,
    ) async {
      await pumpCapture(
        tester,
        const QuickTextCaptureScreen(showGuidedExamples: true),
      );

      await tester.tap(
        find.byKey(const Key('guided_examples_capture_use_style_paused_before_replying')),
      );
      await tester.pump();

      expect(
        find.textContaining('Example style: "I paused before replying."'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('quick_text_capture_field')))
            .controller!
            .text,
        isEmpty,
      );
    });

    test('save stores user words only, not example text', () async {
      const userText = 'I said yes too fast this morning.';

      await AppServices.instance.pipeline.saveTextThought(transcript: userText);

      final all = await AppServices.instance.journalStore.loadAll();
      expect(all, hasLength(1));
      expect(all.single.transcript, userText);
      for (final example in GuidedExamplesCatalog.examples) {
        expect(all.single.transcript, isNot(contains(example.text)));
      }
    });
  });

  group('Record screen integration', () {
    Future<void> pumpRecord(WidgetTester tester, {int entryCount = 0}) async {
      if (entryCount > 0) {
        await tester.runAsync(() async {
          for (var i = 0; i < entryCount; i++) {
            await AppServices.instance.journalStore.save(
              _entry(
                id: 'e$i',
                transcript: 'Real moment $i from the user.',
                createdAt: DateTime(2026, 6, 1 + i, 12),
              ),
            );
          }
        });
      }
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('examples show for first-use users', (tester) async {
      await pumpRecord(tester);

      expect(find.byKey(const Key('guided_examples_card')), findsOneWidget);
      expect(find.text(GuidedExamplesCopy.title), findsOneWidget);
      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
    });

    testWidgets('examples hide after real usage', (tester) async {
      await pumpRecord(tester, entryCount: 2);

      expect(find.byKey(const Key('guided_examples_card')), findsNothing);
      expect(find.byKey(const Key('record_capture_modes_card')), findsOneWidget);
    });

    testWidgets('mic CTA stays above guided examples', (tester) async {
      await pumpRecord(tester);

      final micY = tester.getTopLeft(find.byKey(const Key('capture_entry_record_cta'))).dy;
      final examplesY = tester.getTopLeft(find.byKey(const Key('guided_examples_card'))).dy;
      expect(micY, lessThan(examplesY));
    });
  });

  group('Capture modes still work', () {
    testWidgets('capture modes card remains visible with guided examples', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  GuidedExamplesCard(onUseStyle: (_) {}),
                  RecordCaptureModesCard(onModeTap: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('guided_examples_card')), findsOneWidget);
      expect(find.byKey(const Key('record_capture_modes_card')), findsOneWidget);
      expect(find.text(RecordCaptureModeCopy.cardTitle), findsOneWidget);
    });

    testWidgets('navigateToCaptureMode still opens typed capture', (tester) async {
      for (final mode in RecordCaptureMode.all) {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      unawaited(navigateToCaptureMode(context, mode: mode));
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/quick-capture',
              builder: (context, state) {
                final extra = state.extra! as Map<String, Object?>;
                return QuickTextCaptureScreen(
                  promptHint: extra['prompt'] as String?,
                  helperText: extra['helper'] as String?,
                  captureModeId: extra['captureModeId'] as String?,
                  allowQuietDaySave: extra['allowQuietDaySave'] == true,
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text(mode.helper), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('quick_text_capture_field')))
              .controller!
              .text,
          isEmpty,
        );
      }
    });
  });

  group('First proof unchanged', () {
    test('first proof still builds with guided examples shipped', () {
      final moment = FirstProofMomentEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(moment, isNotNull);
      expect(moment!.hasStrongEvidence, isTrue);
    });
  });
}
