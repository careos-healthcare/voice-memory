import 'dart:io';

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
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/services/app_services.dart';
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
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_insight_quality_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
    ArchiveInsightFeedbackStore.resetForTest();
  });

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
    test('correction note entries expose local preview text', () {
      final beliefId =
          ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate);
      ArchiveInsightFeedbackStore.record(
        beliefId,
        ArchiveInsightFeedbackChoice.notQuite,
      );
      ArchiveInsightFeedbackStore.saveCorrectionNote(beliefId, _privateNote);

      final entries = InsightQualityDashboardEngine.correctionNoteEntries();
      expect(entries.map((entry) => entry.insightId), contains(beliefId));
      expect(entries.single.correctionNote, contains('family'));
    });

    test('delete correction note clears dashboard summary', () {
      final id =
          ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate);
      ArchiveInsightFeedbackStore.saveCorrectionNote(id, _privateNote);
      expect(InsightQualityDashboardEngine.buildSummary().correctionNoteCount, 1);

      ArchiveInsightFeedbackStore.deleteCorrectionNote(id);

      expect(ArchiveInsightFeedbackStore.hasCorrectionNote(id), isFalse);
      expect(InsightQualityDashboardEngine.buildSummary().correctionNoteCount, 0);
    });

    test('unhide restores hidden target visibility state', () {
      final id =
          ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.weeklyReview);
      ArchiveInsightFeedbackStore.hide(id);
      expect(
        ArchiveInsightFeedbackAdaptation.shouldSuppress(
          ArchiveInsightTarget.weeklyReview,
        ),
        isTrue,
      );

      ArchiveInsightFeedbackStore.unhide(id);

      expect(ArchiveInsightFeedbackStore.isHidden(id), isFalse);
      expect(
        ArchiveInsightFeedbackAdaptation.shouldSuppress(
          ArchiveInsightTarget.weeklyReview,
        ),
        isFalse,
      );
    });

    test('clear feedback removes positive and negative counts', () {
      const id = 'archive_home_three';
      ArchiveInsightFeedbackStore.record(id, ArchiveInsightFeedbackChoice.feelsRight);
      ArchiveInsightFeedbackStore.record(id, ArchiveInsightFeedbackChoice.notQuite);

      ArchiveInsightFeedbackStore.clearFeedback(id);

      expect(ArchiveInsightFeedbackStore.feelsRightCount(id), 0);
      expect(ArchiveInsightFeedbackStore.notQuiteCount(id), 0);
      expect(
        InsightQualityDashboardEngine.notQuiteEntries()
            .map((entry) => entry.insightId),
        isNot(contains(id)),
      );
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
        const Offset(0, -300),
      );
      await tester.pump();

      expect(find.byKey(const Key('settings_insight_quality_tile')), findsOneWidget);
      expect(find.text(VisibleArchiveProofCopy.insightQualitySettingsTitle), findsOneWidget);
    });
  });
}
