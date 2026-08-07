import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../models/entitlement.dart';

enum BillingPhase { idle, loading, ready, failed }

@immutable
class BillingState {
  const BillingState({
    this.entitlements,
    this.phase = BillingPhase.idle,
    this.lastFailure,
  });

  final PremiumEntitlements? entitlements;
  final BillingPhase phase;
  final ApiFailure? lastFailure;

  bool get isPro => entitlements?.isPro ?? false;

  BillingState copyWith({
    PremiumEntitlements? entitlements,
    BillingPhase? phase,
    ApiFailure? lastFailure,
    bool clearLastFailure = false,
    bool clearEntitlements = false,
  }) {
    return BillingState(
      entitlements: clearEntitlements
          ? null
          : (entitlements ?? this.entitlements),
      phase: phase ?? this.phase,
      lastFailure: clearLastFailure ? null : (lastFailure ?? this.lastFailure),
    );
  }
}
