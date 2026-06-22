import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback_adaptation.dart';
import 'package:voicememory_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/router/developer_route_guard.dart';
import 'package:voicememory_mobile/screens/insight_quality_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

const _privateNote = 'This is not about work - it is more about family.';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  setUp(ArchiveInsightFeedbackStore.resetForTest);

  group('InsightQualityDashboardEngine', () {
    test('summary counts feels-right feedback', () {
      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        ArchiveInsightFeedbackChoice.feelsRight,
      );
      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        ArchiveInsightFeedbackChoice.feelsRight,
      );

      final summary = InsightQualityDashboardEngine.buildSummary();
      expect(summary.feelsRightCount, 2);
    });

    test('summary counts not-quite feedback', () {
      ArchiveInsightFeedbackStore.record(
        'archive_home_three',
        ArchiveInsightFeedbackChoice.notQuite,
      );
      expect(InsightQualityDashboardEngine.buildSummary().notQuiteCount, 1);
    });

    test('summary counts hidden insights', () {
      ArchiveInsightFeedbackStore.hide('weeklyReview');
      expect(InsightQualityDashboardEngine.buildSummary().hiddenCount, 1);
    });

    test('summary counts correction notes', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote('beliefEvidence', _privateNote);
      expect(InsightQualityDashboardEngine.buildSummary().correctionNoteCount, 1);
    });

    test('friendly labels map known targets', () {
      expect(
        InsightQualityDashboardEngine.friendlyLabel('weeklyReview'),
        VisibleArchiveProofCopy.insightQualityLabelWeeklyReview,
      );
      expect(
        InsightQualityDashboardEngine.friendlyLabel('archive_home_four'),
        VisibleArchiveProofCopy.insightQualityLabelArchiveHomeFour,
      );
    });

    test('dashboard copy avoids banned language', () {
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.insightQualityTitle,
        VisibleArchiveProofCopy.insightQualitySubtitle,
        VisibleArchiveProofCopy.insightQualityPrivacyDevice,
        VisibleArchiveProofCopy.insightQualityPrivacyNotes,
        VisibleArchiveProofCopy.insightQualityPrivacyShareSafe,
        VisibleArchiveProofCopy.insightQualityEmptyBody,
      ]);
    });
  });

  group('InsightQualityScreen', () {
    testWidgets('correction note preview renders locally', (tester) async {
      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        ArchiveInsightFeedbackChoice.notQuite,
      );
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        _privateNote,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const InsightQualityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('insight_quality_screen_title')), findsOneWidget);
      expect(find.text('Insight quality'), findsOneWidget);
      expect(
        find.byKey(
          Key(
            'insight_quality_note_preview_${ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate)}',
          ),
        ),
        findsWidgets,
      );
      expect(find.textContaining('family'), findsWidgets);
    });

    testWidgets('delete correction note removes it from dashboard', (tester) async {
      const id = 'beliefUpdate';
      ArchiveInsightFeedbackStore.saveCorrectionNote(id, _privateNote);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const InsightQualityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(Key('insight_quality_note_$id')), findsOneWidget);

      await tester.dragUntilVisible(
        find.byKey(Key('insight_quality_delete_note_$id')),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pump();

      await tester.tap(find.byKey(Key('insight_quality_delete_note_$id')));
      await tester.pump();
      await tester.pump();

      expect(ArchiveInsightFeedbackStore.hasCorrectionNote(id), isFalse);
      expect(find.byKey(Key('insight_quality_note_$id')), findsNothing);
      expect(
        find.byKey(const Key('insight_quality_summary_correction_notes')),
        findsOneWidget,
      );
      expect(
        (tester.widget<Text>(
          find.byKey(const Key('insight_quality_summary_correction_notes')),
        ).data),
        '0',
      );
    });

    testWidgets('unhide restores hidden target visibility state', (tester) async {
      const id = 'weeklyReview';
      ArchiveInsightFeedbackStore.hide(id);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const InsightQualityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        ArchiveInsightFeedbackAdaptation.shouldSuppress(
          ArchiveInsightTarget.weeklyReview,
        ),
        isTrue,
      );

      await tester.tap(find.byKey(Key('insight_quality_unhide_$id')));
      await tester.pump();
      await tester.pump();

      expect(ArchiveInsightFeedbackStore.isHidden(id), isFalse);
      expect(
        ArchiveInsightFeedbackAdaptation.shouldSuppress(
          ArchiveInsightTarget.weeklyReview,
        ),
        isFalse,
      );
    });

    testWidgets('clear feedback removes positive and negative counts', (
      tester,
    ) async {
      const id = 'archive_home_three';
      ArchiveInsightFeedbackStore.record(id, ArchiveInsightFeedbackChoice.feelsRight);
      ArchiveInsightFeedbackStore.record(id, ArchiveInsightFeedbackChoice.notQuite);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const InsightQualityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(Key('insight_quality_clear_$id')));
      await tester.pump();
      await tester.pump();

      expect(ArchiveInsightFeedbackStore.feelsRightCount(id), 0);
      expect(ArchiveInsightFeedbackStore.notQuiteCount(id), 0);
      expect(find.byKey(Key('insight_quality_not_quite_$id')), findsNothing);
    });

    test('correction notes do not appear in share-safe proof', () {
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        ArchiveInsightFeedbackStore.archiveHomeId(ArchiveHomeStage.fivePlus),
        _privateNote,
      );
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: const [],
      );
      final shareText = proof.lines.join('\n');
      expect(shareText.toLowerCase(), isNot(contains(_privateNote.toLowerCase())));
      expect(shareText.toLowerCase(), isNot(contains('your note:')));
    });
  });

  group('Routing and access', () {
    test('route exists and is reachable when developer routes locked', () {
      expect(DeveloperRouteGuard.redirectFor(InsightQualityNavigation.route), isNull);
    });

    test('route is guarded as sensitive', () {
      expect(
        SensitiveRoutes.isSensitiveRoute(InsightQualityNavigation.route),
        isTrue,
      );
    });

    testWidgets('Settings exposes insight quality link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.dragUntilVisible(
        find.byKey(const Key('settings_insight_quality_tile')),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pump();

      expect(find.byKey(const Key('settings_insight_quality_tile')), findsOneWidget);
      expect(find.text('Manage feedback'), findsOneWidget);
    });
  });
}
