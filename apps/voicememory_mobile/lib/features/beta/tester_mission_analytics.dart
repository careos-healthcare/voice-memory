import '../../services/activation_funnel_analytics.dart';

/// Safe metadata analytics for the tester mission card — no journal text.
abstract final class TesterMissionAnalytics {
  TesterMissionAnalytics._();

  static const seenEvent = 'tester_mission_seen';
  static const dismissedEvent = 'tester_mission_dismissed';

  static void seen({
    required int entryCount,
    required String missionStep,
  }) {
    ActivationFunnelAnalytics.track(
      seenEvent,
      entryCount: entryCount,
      source: 'record',
      stage: missionStep,
      oncePerSession: true,
    );
  }

  static void dismissed({
    required int entryCount,
    required String missionStep,
    required String reason,
  }) {
    ActivationFunnelAnalytics.track(
      dismissedEvent,
      entryCount: entryCount,
      source: 'record',
      stage: missionStep,
      reason: reason,
    );
  }
}
