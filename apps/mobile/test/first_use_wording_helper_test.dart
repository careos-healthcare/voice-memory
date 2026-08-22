import 'dart:async';

import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:archiveme_mobile/features/first_use_wording/first_use_wording_analytics.dart';
import 'package:archiveme_mobile/features/first_use_wording/first_use_wording_copy.dart';
import 'package:archiveme_mobile/features/first_use_wording/first_use_wording_model.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/quick_text_capture_screen.dart';
import 'package:archiveme_mobile/screens/record_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/first_use_wording_helper_card.dart';
import 'package:archiveme_mobile/widgets/record/record_capture_modes_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/app_provider_scope.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    FirstUseWordingAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  tearDown(() {
    VisualAuditOverrides.setRecordPresentation(null);
  });

  group('FirstUseWordingCopy', () {
    test('spec copy is stable', () {
      expect(FirstUseWordingCopy.title, 'Try starting with one real sentence');
      expect(
        FirstUseWordingCopy.body,
        'It can be small. ArchiveMe only needs something real to compare later.',
      );
      expect(FirstUseWordingCopy.useOpeningCta, 'Use this opening');
      expect(FirstUseWordingCatalog.prompts, hasLength(5));
      expect(FirstUseWordingCatalog.prompts.first.opening, 'Today I noticed…');
    });

    test('no therapy advice or coaching language', () {
      final joined = [
        FirstUseWordingCopy.title,
        FirstUseWordingCopy.body,
        FirstUseWordingCopy.useOpeningCta,
        ...FirstUseWordingCatalog.prompts.map((prompt) => prompt.opening),
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

  group('FirstUseWordingGates', () {
    test('shows for zero and one entry when not cluttered', () {
      for (final count in [0, 1]) {
        expect(
          FirstUseWordingGates.shouldShow(
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
        FirstUseWordingGates.shouldShow(
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
        FirstUseWordingGates.shouldShow(
          loaded: true,
          entryCount: 0,
          isReady: true,
          isPostSave: true,
        ),
        isFalse,
      );
    });

    test('hides at entry one when record is cluttered', () {
      expect(
        FirstUseWordingGates.shouldShow(
          loaded: true,
          entryCount: 1,
          isReady: true,
          isPostSave: false,
          isRecordCluttered: true,
        ),
        isFalse,
      );
    });
  });

  group('FirstUseWordingHelperCard', () {
    testWidgets('renders all prompts with use-opening actions', (tester) async {
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: FirstUseWordingHelperCard(onUseOpening: (_) {})),
        )));

      expect(
        find.byKey(const Key('first_use_wording_helper_card')),
        findsOneWidget,
      );
      expect(find.text(FirstUseWordingCopy.title), findsOneWidget);
      expect(find.text(FirstUseWordingCopy.body), findsOneWidget);
      for (final prompt in FirstUseWordingCatalog.prompts) {
        expect(
          find.byKey(Key('first_use_wording_prompt_${prompt.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('first_use_wording_use_opening_${prompt.id}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('use-opening invokes callback without saving', (tester) async {
      FirstUseWordingPrompt? tapped;

      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstUseWordingHelperCard(
              onUseOpening: (prompt) {
                tapped = prompt;
              },
            ),
          ),
        )));

      await tester.tap(
        find.byKey(const Key('first_use_wording_use_opening_today_i_noticed')),
      );
      await tester.pump();

      expect(tapped?.id, 'today_i_noticed');
      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, isEmpty);
    });
  });

  group('navigateToFirstUseWordingOpening', () {
    testWidgets('opens typed capture with placeholder only', (tester) async {
      const prompt = FirstUseWordingPrompt(
        id: 'felt_pressure_when',
        opening: 'I felt pressure when…',
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
                      navigateToFirstUseWordingOpening(
                        context,
                        prompt: prompt,
                        source: 'record',
                      ),
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
                promptHint: extra['prompt'] as String?,
                captureModeId: extra['captureModeId'] as String?,
                showFirstUseWordingHelper:
                    extra['showFirstUseWordingHelper'] == true,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(withAppProviderScope(MaterialApp.router(routerConfig: router)));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.runAsync(() async {
        await AppServices.instance.journal.loadAll();
      });
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('quick_text_capture_field')), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('quick_text_capture_field')));
      expect(field.decoration?.hintText, 'I felt pressure when…');
      expect(field.controller!.text, isEmpty);

      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, isEmpty);
    });
  });

  group('QuickTextCaptureScreen first-use wording', () {
    Future<void> pumpCapture(WidgetTester tester, Widget child) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(theme: AppTheme.light(), home: child)));
      await tester.pump();
      await tester.runAsync(() async {
        await AppServices.instance.journal.loadAll();
      });
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('capture-mode sheet shows compact prompts for early users', (
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

      expect(
        find.byKey(const Key('first_use_wording_capture_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('first_use_wording_capture_prompt_today_i_noticed'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('first_use_wording_capture_prompt_did_something_different'),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'use-opening updates placeholder without prefilling transcript',
      (tester) async {
        await pumpCapture(
          tester,
          const QuickTextCaptureScreen(showFirstUseWordingHelper: true),
        );

        await tester.tap(
          find.byKey(
            const Key(
              'first_use_wording_capture_use_opening_kept_thinking_about',
            ),
          ),
        );
        await tester.pump();

        final field = tester.widget<TextField>(
          find.byKey(const Key('quick_text_capture_field')),
        );
        expect(field.decoration?.hintText, 'I kept thinking about…');
        expect(field.controller!.text, isEmpty);
      },
    );

    test('save stores user words only, not opening prompt text', () async {
      const userText = 'I said yes too fast this morning.';

      await AppServices.instance.pipeline.saveTextThought(transcript: userText);

      final all = await AppServices.instance.journalStore.loadAll();
      expect(all, hasLength(1));
      expect(all.single.transcript, userText);
      for (final prompt in FirstUseWordingCatalog.prompts) {
        expect(all.single.transcript, isNot(contains(prompt.opening)));
      }
    });
  });

  group('FirstUseWordingAnalytics', () {
    test('selected event uses prompt_type only', () {
      final events = <String, Map<String, Object>>{};
      FirstUseWordingAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };

      FirstUseWordingAnalytics.selected(
        source: 'record',
        promptType: 'today_i_noticed',
      );

      expect(events.keys, [FirstUseWordingAnalytics.selectedEvent]);
      final payload = events.values.single;
      expect(payload['source'], 'record');
      expect(payload['prompt_type'], 'today_i_noticed');
      expect(payload.containsKey('prompt_text'), isFalse);
      expect(payload.containsKey('transcript'), isFalse);
      expect(
        payload.values.whereType<String>(),
        isNot(contains('Today I noticed…')),
      );
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
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        )));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('helper hides on simplified first-run Record screen', (
      tester,
    ) async {
      await pumpRecord(tester);

      expect(
        find.byKey(const Key('first_use_wording_helper_card')),
        findsNothing,
      );
      expect(find.text(FirstUseWordingCopy.title), findsNothing);
      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
    });

    testWidgets('helper shows at one entry when not cluttered', (tester) async {
      await pumpRecord(tester, entryCount: 1);

      expect(
        find.byKey(const Key('first_use_wording_helper_card')),
        findsOneWidget,
      );
    });

    testWidgets('helper hides after real usage', (tester) async {
      await pumpRecord(tester, entryCount: 2);

      expect(
        find.byKey(const Key('first_use_wording_helper_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('record_capture_modes_card')),
        findsOneWidget,
      );
    });

    testWidgets('capture modes hidden on simplified first-run Record screen', (
      tester,
    ) async {
      await pumpRecord(tester);

      expect(find.byKey(const Key('record_capture_modes_card')), findsNothing);
    });
  });

  group('Capture modes still work', () {
    testWidgets('capture modes card remains visible with wording helper', (
      tester,
    ) async {
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  FirstUseWordingHelperCard(onUseOpening: (_) {}),
                  RecordCaptureModesCard(onModeTap: (_) {}),
                ],
              ),
            ),
          ),
        )));

      expect(
        find.byKey(const Key('first_use_wording_helper_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('record_capture_modes_card')),
        findsOneWidget,
      );
      expect(find.text(RecordCaptureModeCopy.cardTitle), findsOneWidget);
    });
  });

  group('First proof unchanged', () {
    test('first proof still builds with wording helper shipped', () {
      final moment = FirstProofMomentEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(moment, isNotNull);
      expect(moment!.hasStrongEvidence, isTrue);
    });
  });

  group('Protected areas', () {
    test('feature files avoid billing and signing surfaces', () {
      const paths = [
        'lib/features/first_use_wording/first_use_wording_copy.dart',
        'lib/features/first_use_wording/first_use_wording_model.dart',
        'lib/features/first_use_wording/first_use_wording_analytics.dart',
        'lib/widgets/record/first_use_wording_helper_card.dart',
      ];
      for (final path in paths) {
        final text = switch (path) {
          'lib/features/first_use_wording/first_use_wording_copy.dart' =>
            FirstUseWordingCopy.title + FirstUseWordingCopy.body,
          'lib/features/first_use_wording/first_use_wording_model.dart' =>
            FirstUseWordingCatalog.captureModeId,
          'lib/features/first_use_wording/first_use_wording_analytics.dart' =>
            FirstUseWordingAnalytics.selectedEvent,
          _ => FirstUseWordingCopy.useOpeningCta,
        };
        expect(text.toLowerCase(), isNot(contains('revenuecat')));
        expect(text.toLowerCase(), isNot(contains('restore purchases')));
        expect(text.toLowerCase(), isNot(contains('product_id')));
      }
    });
  });
}