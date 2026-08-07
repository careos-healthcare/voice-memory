import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for the TestFlight feedback email link.
abstract final class TestFlightFeedbackAnalytics {
  TestFlightFeedbackAnalytics._();

  static const tappedEvent = 'testflight_feedback_tapped';

  static void tapped({required String surface}) {
    ActivationFunnelAnalytics.track(tappedEvent, source: surface);
  }
}
