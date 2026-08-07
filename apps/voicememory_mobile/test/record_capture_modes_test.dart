import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/post_save/post_save_archive_hierarchy.dart';
import 'package:voicememory_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/screens/quick_text_capture_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/navigate_to_capture_mode.dart';
import 'package:voicememory_mobile/widgets/record/record_capture_modes_card.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  group('RecordCaptureModeCopy', () {
    test('spec copy is stable', () {
      expect(RecordCaptureModeCopy.cardTitle, 'Start with anything real');
      expect(RecordCaptureModeCopy.cardSubtitle, contains('big moment'));
      expect(RecordCaptureMode.all, hasLength(5));
      expect(RecordCaptureMode.all.map((m) => m.label).toList(), [
        RecordCaptureModeCopy.somethingHappenedLabel,
        RecordCaptureModeCopy.keptThinkingLabel,
        RecordCaptureModeCopy.smallWinLabel,
        RecordCaptureModeCopy.pressureMomentLabel,
        RecordCaptureModeCopy.nothingMuchTodayLabel,
      ]);
    });
  });

  group('RecordCaptureModeEngine', () {
    test('shouldShow on ready Record only', () {
      expect(
        RecordCaptureModeEngine.shouldShow(
          loaded: true,
          isReady: true,
          isPostSave: false,
        ),
        isTrue,
      );
      expect(
        RecordCaptureModeEngine.shouldShow(
          loaded: true,
          isReady: true,
          isPostSave: true,
        ),
        isFalse,
      );
    });

    test('quiet-day text is detected and stays low-signal', () {
      expect(
        RecordCaptureModeEngine.isQuietDayText('Nothing much today.'),
        isTrue,
      );
      final entry = _entry(id: 'q', transcript: 'Nothing much today.');
      expect(RecordCaptureModeEngine.entryIsQuietDay(entry), isTrue);
      final verdict = ArchiveEvidenceQuality.assess(entry);
      expect(verdict.allowsInsights, isFalse);
      expect(
        FirstProofMomentEngine.build(entries: [entry, entry, entry]),
        isNull,
      );
    });

    test('generic test text remains ignored', () {
      final entry = _entry(id: 'g', transcript: 'hello checking mic test');
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback([entry]),
        isTrue,
      );
    });
  });

  group('RecordCaptureModesCard', () {
    testWidgets('shows title and all five modes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: RecordCaptureModesCard(onModeTap: (_) {})),
        ),
      );
      await tester.pump();

      expect(find.text(RecordCaptureModeCopy.cardTitle), findsOneWidget);
      expect(find.text(RecordCaptureModeCopy.cardSubtitle), findsOneWidget);
      for (final mode in RecordCaptureMode.all) {
        expect(find.text(mode.label), findsOneWidget);
      }
    });
  });

  group('QuickTextCaptureScreen capture modes', () {
    Future<void> pumpCaptureScreen(WidgetTester tester, Widget child) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: child),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('opens with prompt and helper without prefilling user text', (
      tester,
    ) async {
      const mode = RecordCaptureMode(
        id: RecordCaptureModeId.somethingHappened,
        label: RecordCaptureModeCopy.somethingHappenedLabel,
        helper: RecordCaptureModeCopy.somethingHappenedHelper,
        prompt: RecordCaptureModeCopy.somethingHappenedPrompt,
      );

      await pumpCaptureScreen(
        tester,
        QuickTextCaptureScreen(
          promptHint: mode.prompt,
          helperText: mode.helper,
          captureModeId: mode.analyticsId,
        ),
      );

      expect(
        find.byKey(const Key('quick_text_capture_mode_helper')),
        findsOneWidget,
      );
      expect(
        find.text(RecordCaptureModeCopy.somethingHappenedHelper),
        findsOneWidget,
      );
      expect(
        find.text(RecordCaptureModeCopy.somethingHappenedPrompt),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('quick_text_capture_field')),
            )
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('quiet-day mode shows save-as-quiet-day action', (
      tester,
    ) async {
      await pumpCaptureScreen(
        tester,
        const QuickTextCaptureScreen(
          promptHint: RecordCaptureModeCopy.nothingMuchTodayPrompt,
          helperText: RecordCaptureModeCopy.nothingMuchTodayHelper,
          allowQuietDaySave: true,
        ),
      );

      expect(
        find.byKey(const Key('quick_text_capture_quiet_day_save')),
        findsOneWidget,
      );
      expect(
        find.text(RecordCaptureModeCopy.quietDaySaveButton),
        findsOneWidget,
      );
    });

    test('quiet-day save stores default phrase only', () async {
      await AppServices.instance.pipeline.saveTextThought(
        transcript: RecordCaptureModeEngine.quietDaySaveText(),
      );

      final all = await AppServices.instance.journalStore.loadAll();
      expect(all, hasLength(1));
      expect(
        all.single.transcript,
        RecordCaptureModeCopy.quietDayDefaultSaveText,
      );
      expect(
        all.single.transcript,
        isNot(contains(RecordCaptureModeCopy.nothingMuchTodayHelper)),
      );
    });

    test('typed capture stores user words only', () async {
      const userText =
          'I finally finished the small task I had been putting off today.';

      await AppServices.instance.pipeline.saveTextThought(transcript: userText);

      final all = await AppServices.instance.journalStore.loadAll();
      expect(all.single.transcript, userText);
      expect(all.single.transcript, isNot(contains('went a little better')));
    });
  });

  group('navigateToCaptureMode', () {
    testWidgets('opens typed capture with mode prompt and helper', (
      tester,
    ) async {
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
          find.byKey(const Key('quick_text_capture_mode_helper')),
          findsOneWidget,
        );
        expect(find.text(mode.prompt), findsOneWidget);
      }
    });
  });

  group('Post-save capture mode copy', () {
    test('quiet-day hierarchy uses quiet-day footnote', () {
      final entries = [_entry(id: 'q', transcript: 'Nothing much today.')];
      final hierarchy = PostSaveArchiveHierarchy.resolve(
        entries: entries,
        suppressLatestSaveArchiveInsight: true,
      );
      expect(hierarchy.kind, PostSavePrimaryArchiveKind.quietDay);
    });

    test('no-repeat saved privately uses non-failure reassurance copy', () {
      expect(
        PostSaveRecordedSummaryCopy.noPatternReassurance,
        contains('does not need every entry to become a pattern'),
      );
    });
  });
}
