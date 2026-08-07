import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:voicememory_mobile/features/pattern_review_inbox/pattern_review_inbox_analytics.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_analytics.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_dismiss_store.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_analytics.dart';
import 'package:voicememory_mobile/features/monthly_private_report/monthly_private_report_dismiss_store.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:voicememory_mobile/billing/paywall_session_tracker.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_analytics.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_dismiss_store.dart';
import 'package:voicememory_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import 'package:voicememory_mobile/features/pro_evidence_value/pro_evidence_value_analytics.dart';
import 'package:voicememory_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:voicememory_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_analytics.dart';
import 'package:voicememory_mobile/features/quiet_signal/quiet_signal_analytics.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

/// Clears static in-memory caches that leak across release-suite test files.
abstract final class ReleaseSuiteStaticStateReset {
  ReleaseSuiteStaticStateReset._();

  /// Safe before each test even when [AppServices] is not initialized.
  static Future<void> resetCachedState() async {
    AppConfig.configureForTest();
    await ComeBackTomorrowV2Store.resetForTest(null);
    FirstProofTruthStore.invalidateCache();
    WhatChangedV2Store.invalidateCache();
    HelpedTrackingStore.invalidateCache();
    PatternNameStore.resetForTest();
    MicrophonePermissionEnvironment.resetForTest();
    PatternReviewInboxAnalytics.resetForTest();
    QuietSignalAnalytics.resetForTest();
    ProEvidenceValueAnalytics.resetForTest();
    ProEvidenceValueDismissStore.invalidateSessionForTest();
    ProLockMomentAnalytics.resetForTest();
    ProLockMomentDismissStore.invalidateSessionForTest();
    MonthlyPrivateReportAnalytics.resetForTest();
    MonthlyPrivateReportDismissStore.invalidateSessionForTest();
    ArchiveBackupBridgeAnalytics.resetForTest();
    ArchiveBackupBridgeDismissStore.invalidateSessionForTest();
    BetaFeedbackIntelligenceAnalytics.resetForTest();
    BetaFeedbackIntelligenceStore.invalidateSessionForTest();
    RevenueFunnelAnalytics.resetForTest();
    DelayedPaywallProofStore.bypassGateForTest = true;
    livePaywallSessionTracker.resetSession();
  }

  /// Clears prefs-backed state after [AppServices.resetForTest].
  static Future<void> resetPrefsBackedState(MobilePrefsStore prefs) async {
    await ComeBackTomorrowV2Store.resetForTest(prefs);
    await FirstProofTruthStore.resetForTest(prefs);
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
    PatternNameStore.resetForTest();
  }
}
