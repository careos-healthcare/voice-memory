/// Outcome of a native RevenueCat paywall presentation attempt.
enum PaywallResult {
  /// User completed a purchase and entitlement verification succeeded.
  purchased,

  /// User restored a prior purchase and entitlement verification succeeded.
  restored,

  /// User dismissed the paywall without unlocking entitlement.
  cancelled,

  /// Native bridge or execution pipeline failed structurally.
  failed,

  /// Paywall gate blocked native UI; app routed to `/subscription` instead.
  fallbackRoute,

  /// Native UI was not presented (for example, user already entitled).
  notPresented,
}
