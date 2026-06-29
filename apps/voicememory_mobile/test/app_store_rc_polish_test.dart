import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/config/release_config.dart';
import 'package:voicememory_mobile/config/screenshot_mode.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/activation/archive_evidence_map.dart';
import 'package:voicememory_mobile/features/activation/archive_health_action_plan.dart';
import 'package:voicememory_mobile/features/activation/archive_health_score.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_layout.dart';
import 'package:voicememory_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/activation/context_insights.dart';
import 'package:voicememory_mobile/features/activation/evidence_attention_filters.dart';
import 'package:voicememory_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/activation/belief_history_timeline.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/share/archive_share_text.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/security/privacy_data_controls_copy.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';
import 'package:voicememory_mobile/widgets/settings/privacy_data_controls_dialogs.dart';
import 'package:voicememory_mobile/widgets/settings/privacy_data_controls_section.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
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
      captureContextTag: captureContextTag,
    );

List<JournalEntry> _distinctEntries(int count) {
  final transcripts = [
    'I felt pressure at work before saying yes again even when I was tired moment one.',
    'Work kept pulling me back after I wanted to stop for the day moment two.',
    'I noticed the same hurry showing up before I answered anyone moment three.',
    'The deadline pressure returned, but I caught it earlier this time moment four.',
    'Another work moment before I could leave for the day moment five.',
  ];
  return List.generate(
    count,
    (index) => _voiceEntry(
      id: 'e${index + 1}',
      transcript: transcripts[index],
      createdAt: DateTime(2026, 6, 9 + index, 12),
      captureContextTag: index.isEven
          ? CaptureContextTagIds.work
          : CaptureContextTagIds.home,
    ),
  );
}

const _minReleaseCandidateBuild = 38;

void main() {
  setUp(ArchiveInsightFeedbackStore.resetForTest);

  group('App Store release candidate', () {
    test('app identity remains ArchiveMe with unchanged bundle id', () {
      expect(AppConfig.appName, 'ArchiveMe');

      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleDisplayName</key>'));
      expect(plist, contains('<string>ArchiveMe</string>'));

      final pbxproj =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = com.voicememory.mobile;'));
    });

    test('pubspec build number is ready for next App Store upload', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', multiLine: true)
          .firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec version line missing');
      final build = int.parse(match!.group(2)!);
      expect(build, greaterThanOrEqualTo(_minReleaseCandidateBuild));
    });

    test('Type instead label is canonical across capture surfaces', () {
      expect(EmptyArchiveCopy.typeInsteadCta, VisibleArchiveProofCopy.typeInsteadCta);
      expect(MicrophonePermissionCopy.typeInsteadCta, VisibleArchiveProofCopy.typeInsteadCta);
      expect(VisibleArchiveProofCopy.typeInsteadCta, 'Type instead');
    });

    testWidgets('typed capture path remains available on Record', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: CaptureEntryActions(onRecord: () {})),
        ),
      );
      await tester.pump();

      expect(find.text(VisibleArchiveProofCopy.typeInsteadCta), findsOneWidget);
      expect(
        File('lib/router/app_router.dart').readAsStringSync(),
        contains("path: '/quick-capture'"),
      );
    });

    testWidgets('privacy and data controls are visible in Settings section', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PrivacyDataControlsSection()),
        ),
      );
      await tester.pump();

      expect(find.text(PrivacyDataControlsCopy.sectionTitle), findsOneWidget);
      expect(find.byKey(const Key('privacy_data_stays_on_device_tile')), findsOneWidget);
      expect(find.byKey(const Key('privacy_data_export_archive_tile')), findsOneWidget);
      expect(find.byKey(const Key('privacy_data_clear_local_archive_tile')), findsOneWidget);
    });

    testWidgets('clear local archive requires confirmation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showClearLocalArchiveDialog(context),
                child: const Text('clear'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('clear'));
      await tester.pump();

      expect(find.byKey(const Key('clear_local_archive_cancel')), findsOneWidget);
      expect(find.byKey(const Key('clear_local_archive_confirm')), findsOneWidget);
    });

    test('share-safe proof excludes private archive data', () {
      const engine = ShareableArchiveProofEngine();
      const sensitive =
          'Maria told me about the divorce paperwork at the hospital again';
      ArchiveInsightFeedbackStore.saveCorrectionNote(
        'beliefEvidence',
        'This felt more about hurry than pressure.',
      );

      final proof = engine.buildFromJournal(
        entries: List.generate(
          5,
          (i) => _voiceEntry(
            id: 'e$i',
            transcript: sensitive,
            createdAt: DateTime(2026, 6, 9 + i, 12),
            captureContextTag: CaptureContextTagIds.work,
          ),
        ),
      );
      final shareText = proof.shareText.toLowerCase();

      expect(proof.hasProof, isTrue);
      expect(shareText, isNot(contains('maria')));
      expect(shareText, isNot(contains('divorce')));
      expect(shareText, isNot(contains('hospital')));
      expect(shareText, isNot(contains('work')));
      expect(shareText, isNot(contains('untagged')));
      expect(shareText, isNot(contains('filter')));
      expect(shareText, isNot(contains('map')));
      expect(shareText, isNot(contains('hurry')));
      expect(shareText, contains('no private entries shared.'));
      expect(ArchiveShareText.includesBannedConsumerCopy(proof.shareText), isFalse);
    });

    test('sensitive routes include insight quality and evidence map drilldowns', () {
      expect(SensitiveRoutes.isSensitiveRoute('/insight-quality'), isTrue);
      expect(
        SensitiveRoutes.isSensitiveRoute(
          ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.work),
        ),
        isTrue,
      );
      expect(
        SensitiveRoutes.isSensitiveRoute(
          ArchiveEvidenceMapNavigation.contextPath(ArchiveEvidenceMapRowIds.untagged),
        ),
        isTrue,
      );
      expect(SensitiveRoutes.isSensitiveRoute('/about'), isFalse);
      expect(InsightQualityNavigation.route, '/insight-quality');
    });

    test('0/1/2/3/5+ archive states stay calm and gated', () {
      for (final count in [0, 1, 2, 3, 5]) {
        final entries = count == 0 ? const <JournalEntry>[] : _distinctEntries(count);
        final home = ArchiveHomeSummaryEngine.build(entries: entries);
        final beliefHistory = count >= 5
            ? BeliefHistoryTimelineEngine.build(entries: entries)
            : null;
        final weeklyReview = count >= 5
            ? WeeklyArchiveReviewEngine.build(entries: entries)
            : null;
        final layout = ArchiveWorkspaceLayoutEngine.build(
          entries: entries,
          archiveHome: home,
          attentionFilters: EvidenceAttentionFiltersEngine.build(entries: entries),
          actionPlan: ArchiveHealthActionPlanEngine.build(entries: entries),
          archiveHealth: ArchiveHealthScoreEngine.build(entries: entries),
          contextInsights: ContextInsightsEngine.build(entries: entries),
          evidenceMap: ArchiveEvidenceMapEngine.build(entries: entries),
          beliefHistory: beliefHistory,
          weeklyReview: weeklyReview,
          shareProof: const ShareableArchiveProofEngine().buildFromJournal(
            entries: entries,
          ),
        );
        final quickActions = ArchiveWorkspaceQuickActionsEngine.build(
          entries: entries,
          archiveHome: home,
          workspaceLayout: layout,
          evidenceMapVisible: layout.showEvidenceMap,
        );

        expect(layout.reviewHistory.show, count >= 5);
        if (count <= 1) {
          expect(layout.evidenceQuality.show, isFalse);
          expect(quickActions.showCard, isFalse);
        }
        if (count == 3) {
          expect(layout.evidenceQuality.show, isTrue);
          expect(home.body.toLowerCase(), contains('saved words suggest so far'));
        }
        expect(home.title.toLowerCase(), isNot(contains('voicememory')));
      }
    });

    test('no user-facing VoiceMemory in RC copy constants', () {
      const scanned = [
        VisibleArchiveProofCopy.recordHeroBody,
        VisibleArchiveProofCopy.archiveHomeEmptyBody,
        VisibleArchiveProofCopy.firstSaveBody,
        PrivacyDataControlsCopy.dataStaysOnDeviceBody,
        ConsumerUiCopy.paywallBillingNotConfigured,
        ConsumerUiCopy.paywallSetupUnavailableBody,
      ];
      for (final text in scanned) {
        expect(text, isNot(contains('VoiceMemory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
    });

    test('RevenueCat unconfigured copy stays calm and non-technical', () {
      expect(
        ConsumerUiCopy.paywallBillingNotConfigured.toLowerCase(),
        isNot(contains('revenuecat')),
      );
      expect(
        ConsumerUiCopy.paywallSetupUnavailableBody.toLowerCase(),
        isNot(contains('revenuecat')),
      );
      expect(ConsumerUiCopy.paywallBillingNotConfigured, contains('ArchiveMe'));
      expect(
        ConsumerUiCopy.paywallSetupUnavailableBody,
        contains('not available'),
      );

      final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(settings, contains('isConfigured'));
      expect(settings, contains('SubscriptionCopy.temporarilyUnavailable'));
    });

    test('debug and screenshot modes stay hidden by default', () {
      DeveloperSettingsGate.resetForTest();
      expect(ScreenshotMode.enabled, isFalse);
      expect(ReleaseConfig.screenshotCaptureActive, isFalse);
      expect(DeveloperSettingsGate.canShowDeveloperSettings, isFalse);
    });
  });
}
