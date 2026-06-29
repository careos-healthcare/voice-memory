import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../services/activation_funnel_analytics.dart';

/// Lightweight analytics for the early archive proof loop — counts and
/// stable surface ids only; never journal text.
abstract final class EarlyArchiveProofAnalytics {
  EarlyArchiveProofAnalytics._();

  static const String demoCtaSeenEvent = 'archiveme_demo_cta_seen';
  static const String demoOpenedEvent = 'archiveme_demo_opened';
  static const String demoHiddenEvent = 'archiveme_demo_hidden';
  static const String heardReceiptSeenEvent =
      'early_archive_heard_receipt_seen';
  static const String possiblePatternSeenEvent =
      'early_archive_possible_pattern_seen';
  static const String confirmedRepeatSeenEvent =
      'early_archive_confirmed_repeat_seen';
  static const String triggerPromptTappedEvent =
      'early_archive_trigger_prompt_tapped';
  static const String triggerPayoffSeenEvent =
      'early_archive_trigger_payoff_seen';
  static const String softeningNoticeSeenEvent =
      'early_archive_softening_notice_seen';
  static const String helpfulActionPromptTappedEvent =
      'early_archive_helpful_action_prompt_tapped';
  static const String helpfulActionPayoffSeenEvent =
      'early_archive_helpful_action_payoff_seen';
  static const String timelineSeenEvent = 'early_archive_timeline_seen';
  static const String timelineViewEvidenceTappedEvent =
      'early_archive_timeline_view_evidence_tapped';
  static const String proScreenOpenedAfterTimelineEvent =
      'pro_screen_opened_after_timeline';

  static bool _realTimelineSeenThisSession = false;

  @visibleForTesting
  static bool get realTimelineSeenThisSession => _realTimelineSeenThisSession;

  @visibleForTesting
  static void resetForTest() {
    _realTimelineSeenThisSession = false;
  }

  static void markRealTimelineSeen() {
    _realTimelineSeenThisSession = true;
  }

  static void demoCtaSeen({
    required int entryCount,
    required String surface,
  }) {
    _track(
      demoCtaSeenEvent,
      entryCount: entryCount,
      source: surface,
      hasRealTimeline: false,
      oncePerSession: true,
      sessionStage: 'demo_cta',
    );
  }

  static void demoOpened({
    required int entryCount,
    required String surface,
  }) {
    _track(
      demoOpenedEvent,
      entryCount: entryCount,
      source: surface,
      hasRealTimeline: false,
    );
  }

  static void demoHidden({
    required int entryCount,
    required String surface,
  }) {
    _track(
      demoHiddenEvent,
      entryCount: entryCount,
      source: surface,
      hasRealTimeline: false,
    );
  }

  static void heardReceiptSeen({
    required int entryCount,
    required String surface,
  }) {
    _track(
      heardReceiptSeenEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'one_entry_receipt',
      oncePerSession: true,
      sessionStage: 'one_entry_receipt',
    );
  }

  static void possiblePatternSeen({
    required int entryCount,
    required String surface,
  }) {
    _track(
      possiblePatternSeenEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'two_entry_first_signal',
      oncePerSession: true,
      sessionStage: 'two_entry_first_signal',
    );
  }

  static void confirmedRepeatSeen({
    required int entryCount,
    required String surface,
  }) {
    _track(
      confirmedRepeatSeenEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'three_entry_confirmed_repeat',
      oncePerSession: true,
      sessionStage: 'three_entry_confirmed_repeat',
    );
  }

  static void triggerPromptTapped({
    required int entryCount,
    required String surface,
  }) {
    _track(
      triggerPromptTappedEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'trigger_prompt',
    );
  }

  static void triggerPayoffSeen({
    required int entryCount,
    required String surface,
  }) {
    _track(
      triggerPayoffSeenEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'trigger_payoff',
      oncePerSession: true,
      sessionStage: 'trigger_payoff',
    );
  }

  static void softeningNoticeSeen({
    required int entryCount,
    required String surface,
  }) {
    _track(
      softeningNoticeSeenEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'softening_notice',
      oncePerSession: true,
      sessionStage: 'softening_notice',
    );
  }

  static void helpfulActionPromptTapped({
    required int entryCount,
    required String surface,
  }) {
    _track(
      helpfulActionPromptTappedEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'helpful_action_prompt',
    );
  }

  static void helpfulActionPayoffSeen({
    required int entryCount,
    required String surface,
  }) {
    _track(
      helpfulActionPayoffSeenEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'helpful_action_payoff',
      oncePerSession: true,
      sessionStage: 'helpful_action_payoff',
    );
  }

  static void timelineSeen({
    required int entryCount,
    required String surface,
    required int milestoneCount,
    required bool hasRealTimeline,
    bool compact = false,
  }) {
    if (hasRealTimeline) {
      markRealTimelineSeen();
    }
    _track(
      timelineSeenEvent,
      entryCount: entryCount,
      source: surface,
      milestoneCount: milestoneCount,
      hasRealTimeline: hasRealTimeline,
      stage: compact ? 'compact' : 'full',
      oncePerSession: true,
      sessionStage: 'timeline_${compact ? 'compact' : 'full'}',
    );
  }

  static void timelineViewEvidenceTapped({
    required int entryCount,
    required String surface,
    required bool hasRealTimeline,
  }) {
    _track(
      timelineViewEvidenceTappedEvent,
      entryCount: entryCount,
      source: surface,
      hasRealTimeline: hasRealTimeline,
      stage: 'view_evidence',
    );
  }

  static void proScreenOpenedAfterTimeline({required String source}) {
    if (!_realTimelineSeenThisSession) return;
    _track(
      proScreenOpenedAfterTimelineEvent,
      source: source,
      hasRealTimeline: true,
      oncePerSession: true,
      sessionStage: 'pro_after_timeline',
    );
  }

  static void _track(
    String event, {
    int? entryCount,
    String? source,
    String? stage,
    int? milestoneCount,
    bool? hasRealTimeline,
    bool oncePerSession = false,
    String? sessionStage,
  }) {
    ActivationFunnelAnalytics.track(
      event,
      entryCount: entryCount,
      source: source,
      stage: stage ?? sessionStage,
      milestoneCount: milestoneCount,
      hasRealTimeline: hasRealTimeline,
      oncePerSession: oncePerSession,
    );
  }
}
