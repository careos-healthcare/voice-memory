/// Session-scoped paywall display flags — one instance per app session.
class PaywallSessionTracker {
  bool _objectionFollowUpShown = false;

  bool get objectionFollowUpShown => _objectionFollowUpShown;

  void markShown() {
    _objectionFollowUpShown = true;
  }

  void resetSession() {
    _objectionFollowUpShown = false;
  }
}

/// Shared tracker for production paywall flows. Tests inject their own instance.
final PaywallSessionTracker livePaywallSessionTracker = PaywallSessionTracker();