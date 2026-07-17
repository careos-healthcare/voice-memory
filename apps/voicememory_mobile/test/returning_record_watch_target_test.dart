import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_model.dart';
import 'package:voicememory_mobile/features/record/returning_record_watch_target_ui_gates.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/daily_archive_memory_card.dart';

void main() {
  group('ReturningRecordWatchTargetUiGates', () {
    test('focused surface only when daily memory has watch target', () {
      const watch = DailyArchiveMemoryResult(
        title: DailyArchiveMemoryCopy.watchTitle,
        body: DailyArchiveMemoryCopy.watchBody,
        watchPhrase: 'checking again',
        footer: DailyArchiveMemoryCopy.footer,
        hasWatchTarget: true,
        canShowPatternDetail: false,
      );

      expect(
        ReturningRecordWatchTargetUiGates.showFocusedSurface(
          showDailyArchiveMemory: true,
          dailyArchiveMemory: watch,
        ),
        isTrue,
      );
      expect(
        ReturningRecordWatchTargetUiGates.showFocusedSurface(
          showDailyArchiveMemory: true,
          dailyArchiveMemory: const DailyArchiveMemoryResult(
            title: DailyArchiveMemoryCopy.fallbackTitle,
            body: DailyArchiveMemoryCopy.fallbackBody,
            hasWatchTarget: false,
            canShowPatternDetail: false,
          ),
        ),
        isFalse,
      );
    });

    test('suppresses competing ready guidance when focused', () {
      expect(
        ReturningRecordWatchTargetUiGates.suppressCompetingReadyGuidance(
          showFocusedSurface: true,
        ),
        isTrue,
      );
      expect(
        ReturningRecordWatchTargetUiGates.suppressCompetingReadyGuidance(
          showFocusedSurface: false,
        ),
        isFalse,
      );
    });

    test('suppresses archive education stack when focused', () {
      expect(
        ReturningRecordWatchTargetUiGates.suppressArchiveEducationStack(
          showFocusedSurface: true,
        ),
        isTrue,
      );
      expect(
        ReturningRecordWatchTargetUiGates.suppressArchiveEducationStack(
          showFocusedSurface: false,
        ),
        isFalse,
      );
    });

    test('watchPromptSkippedToday is false by default', () {
      expect(
        ReturningRecordWatchTargetUiGates.watchPromptSkippedToday(),
        isFalse,
      );
      expect(
        ReturningRecordWatchTargetUiGates.suppressDailyStreakPressureToday(),
        isFalse,
      );
    });

    test('showProUpgradePromptOnReturn from first saved entry', () {
      expect(
        ReturningRecordWatchTargetUiGates.showProUpgradePromptOnReturn(
          entryCount: 0,
        ),
        isFalse,
      );
      expect(
        ReturningRecordWatchTargetUiGates.showProUpgradePromptOnReturn(
          entryCount: 1,
        ),
        isTrue,
      );
      expect(
        ReturningRecordWatchTargetUiGates.showProUpgradePromptOnReturn(
          entryCount: 3,
        ),
        isTrue,
      );
    });

    test('beta record surfaces require beta mission and exclude app review', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      ArchiveAppReviewAccessGate.enabledOverride = false;
      addTearDown(() {
        ArchiveBetaMissionGate.resetForTest();
        ArchiveAppReviewAccessGate.resetForTest();
      });

      expect(ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces(), isTrue);

      ArchiveBetaMissionGate.enabledOverride = false;
      expect(ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces(), isFalse);

      ArchiveBetaMissionGate.enabledOverride = true;
      ArchiveAppReviewAccessGate.enabledOverride = true;
      expect(ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces(), isFalse);
    });
  });

  group('DailyArchiveMemoryCard focused returning UI', () {
    testWidgets('watch target shows focused copy and capture actions', (
      tester,
    ) async {
      var recordTapped = false;
      var typeTapped = false;
      var notTodayTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DailyArchiveMemoryCard(
              memory: const DailyArchiveMemoryResult(
                title: DailyArchiveMemoryCopy.watchTitle,
                body: DailyArchiveMemoryCopy.watchBody,
                watchPhrase: 'checking again',
                footer: DailyArchiveMemoryCopy.footer,
                hasWatchTarget: true,
                canShowPatternDetail: false,
              ),
              entryCount: 3,
              source: 'record',
              showFocusedCaptureActions: true,
              onRecord: () => recordTapped = true,
              onTypeInstead: () => typeTapped = true,
              onNotToday: () => notTodayTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(DailyArchiveMemoryCopy.watchPrompt('checking again')),
        findsOneWidget,
      );
      expect(find.text('Record what happened'), findsOneWidget);
      expect(find.text(DailyArchiveMemoryCopy.typeInsteadCta), findsOneWidget);
      expect(find.text(DailyArchiveMemoryCopy.notTodayCta), findsOneWidget);
      expect(find.byKey(const Key('daily_archive_memory_title')), findsNothing);
      expect(find.text(ConsumerUiCopy.recordTitle), findsNothing);
      expect(find.text(RecordCaptureModeCopy.somethingHappenedLabel), findsNothing);
      expect(find.text('Log pressure moment'), findsNothing);

      await tester.tap(find.text('Record what happened'));
      await tester.pump();
      expect(recordTapped, isTrue);

      await tester.tap(find.text(DailyArchiveMemoryCopy.typeInsteadCta));
      await tester.pump();
      expect(typeTapped, isTrue);

      await tester.tap(find.text(DailyArchiveMemoryCopy.notTodayCta));
      await tester.pump();
      expect(notTodayTapped, isTrue);
      expect(find.byKey(const Key('daily_archive_memory_card')), findsNothing);
      expect(find.textContaining('streak'), findsNothing);
      expect(find.textContaining('missed'), findsNothing);
      expect(find.textContaining('homework'), findsNothing);
    });
  });
}
