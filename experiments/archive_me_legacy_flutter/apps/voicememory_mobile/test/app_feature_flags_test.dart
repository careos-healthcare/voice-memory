import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_feature_flags.dart';
import 'package:voicememory_mobile/config/archive_differentiation_preview.dart';
import 'package:voicememory_mobile/config/archive_intelligence_preview.dart';
import 'package:voicememory_mobile/config/archive_me_demo_state.dart';
import 'package:voicememory_mobile/config/creator_demo_mode.dart';
import 'package:voicememory_mobile/config/first_three_session_preview.dart';
import 'package:voicememory_mobile/config/screenshot_mode.dart';

void main() {
  tearDown(AppFeatureFlags.testOverrides.reset);

  test('legacy preview adapters read centralized compile-time flags', () {
    expect(ScreenshotMode.enabled, AppFeatureFlags.screenshotModeEnabled);
    expect(ScreenshotMode.recordView, AppFeatureFlags.screenshotRecordView);
    expect(
      ArchiveDifferentiationPreview.archiveBelief,
      AppFeatureFlags.archiveBeliefPreview,
    );
    expect(
      ArchiveDifferentiationPreview.evidenceTimeline,
      AppFeatureFlags.evidenceTimelinePreview,
    );
    expect(
      ArchiveDifferentiationPreview.weeklyReview,
      AppFeatureFlags.weeklyReviewPreview,
    );
    expect(FirstThreeSessionPreview.forcedSession, isNull);
    expect(ArchiveIntelligencePreview.forcedTier, isNull);
  });

  test('demo test overrides are isolated and centrally reset', () {
    ArchiveMeDemoState.debugForceEnabledForTest = true;
    CreatorDemoMode.debugForceEnabledForTest = true;

    expect(AppFeatureFlags.testOverrides.archiveMeDemoEnabled, isTrue);
    expect(AppFeatureFlags.testOverrides.creatorDemoEnabled, isTrue);
    expect(ArchiveMeDemoState.isActive, isTrue);
    expect(CreatorDemoMode.isActive, isTrue);

    AppFeatureFlags.testOverrides.reset();

    expect(ArchiveMeDemoState.debugForceEnabledForTest, isFalse);
    expect(CreatorDemoMode.debugForceEnabledForTest, isFalse);
  });
}
