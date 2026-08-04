import 'dart:async';

import '../config/trial_mode.dart';
import '../features/monetization/domain/access_policy_engine.dart';
import '../services/app_services.dart';
import '../subscriptions/domain/subscription_models.dart';

/// Reads whether the user has ArchiveMe Pro — injectable for tests.
abstract class ArchiveEntitlementReader {
  const ArchiveEntitlementReader();

  Future<EntitlementSnapshot> get entitlement;

  @Deprecated('Evaluate a CapabilityId through AccessPolicyEngine.')
  Future<bool> get isPro;

  static ArchiveEntitlementReader instance() => _LiveArchiveEntitlementReader();

  /// Trial builds skip paywall gates so facilitators can test the full loop.
  static ArchiveEntitlementReader forAccessCheck() {
    if (TrialMode.enabled) return const _ProArchiveEntitlementReader();
    return instance();
  }
}

class _LiveArchiveEntitlementReader extends ArchiveEntitlementReader {
  @override
  Future<EntitlementSnapshot> get entitlement async {
    if (!AppServices.isInitialized) return const EntitlementSnapshot.unknown();
    final repository = AppServices.instance.subscriptionRepository;
    final cached = await repository.loadCachedState();
    unawaited(repository.refresh(force: true));
    return cached == null
        ? const EntitlementSnapshot.unknown()
        : EntitlementSnapshot.fromSubscriptionState(cached);
  }

  @override
  Future<bool> get isPro async => (await entitlement).hasProAccess;
}

class _ProArchiveEntitlementReader extends ArchiveEntitlementReader {
  const _ProArchiveEntitlementReader();

  @override
  Future<EntitlementSnapshot> get entitlement async =>
      const EntitlementSnapshot(
        plan: PlanKind.pro,
        status: EntitlementStatus.active,
      );

  @override
  Future<bool> get isPro async => true;
}

/// Fixed entitlement for widget tests.
class FakeArchiveEntitlementReader extends ArchiveEntitlementReader {
  @override
  Future<EntitlementSnapshot> get entitlement async => pro
      ? const EntitlementSnapshot(
          plan: PlanKind.pro,
          status: EntitlementStatus.active,
        )
      : const EntitlementSnapshot.free();

  FakeArchiveEntitlementReader({required this.pro});

  final bool pro;

  @override
  Future<bool> get isPro async => pro;
}

extension SubscriptionStatePro on SubscriptionState {
  bool get archiveProAccess => isPro;
}
