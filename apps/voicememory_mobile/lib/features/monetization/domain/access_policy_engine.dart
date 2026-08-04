import '../../../subscriptions/domain/subscription_models.dart';
import 'generated/monetization_policy.g.dart';

export 'generated/monetization_policy.g.dart';

enum EntitlementStatus {
  free,
  trial,
  active,
  gracePeriod,
  billingIssue,
  expired,
  revoked,
  legacyGrandfathered,
  unknown,
}

enum AccessDecisionReason {
  userOwned,
  existingGeneratedOutput,
  freeProofAvailable,
  proEntitled,
  allowanceAvailable,
  alreadyGenerated,
  proRequired,
  allowanceNotConfigured,
  allowanceExhausted,
  entitlementUnknown,
}

enum AccessDecisionKind {
  allowed,
  allowedAsFreeProof,
  allowedReadOnly,
  requiresPro,
  usageAllowanceReached,
  entitlementTemporarilyUnknown,
  offeringUnavailable,
  configurationMissing,
  unavailable,
}

class AccessDecision {
  AccessDecision._({
    required this.allowed,
    required this.kind,
    required this.reason,
  });

  AccessDecision.allow(AccessDecisionReason reason)
    : this._(allowed: true, kind: _kindFor(reason), reason: reason);

  AccessDecision.deny(AccessDecisionReason reason)
    : this._(allowed: false, kind: _kindFor(reason), reason: reason);

  final bool allowed;
  final AccessDecisionKind kind;
  final AccessDecisionReason reason;

  static AccessDecisionKind _kindFor(AccessDecisionReason reason) =>
      switch (reason) {
        AccessDecisionReason.freeProofAvailable =>
          AccessDecisionKind.allowedAsFreeProof,
        AccessDecisionReason.existingGeneratedOutput =>
          AccessDecisionKind.allowedReadOnly,
        AccessDecisionReason.proRequired => AccessDecisionKind.requiresPro,
        AccessDecisionReason.allowanceExhausted =>
          AccessDecisionKind.usageAllowanceReached,
        AccessDecisionReason.entitlementUnknown =>
          AccessDecisionKind.entitlementTemporarilyUnknown,
        AccessDecisionReason.allowanceNotConfigured =>
          AccessDecisionKind.configurationMissing,
        AccessDecisionReason.alreadyGenerated => AccessDecisionKind.unavailable,
        _ => AccessDecisionKind.allowed,
      };
}

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.plan,
    required this.status,
    this.verifiedAt,
  });

  const EntitlementSnapshot.free()
    : this(plan: PlanKind.free, status: EntitlementStatus.free);

  const EntitlementSnapshot.unknown()
    : this(plan: PlanKind.free, status: EntitlementStatus.unknown);

  final PlanKind plan;
  final EntitlementStatus status;
  final DateTime? verifiedAt;

  bool get hasProAccess =>
      (status == EntitlementStatus.trial ||
          status == EntitlementStatus.active ||
          status == EntitlementStatus.gracePeriod ||
          status == EntitlementStatus.legacyGrandfathered) &&
      (plan == PlanKind.pro || plan == PlanKind.legacyGrandfathered);

  factory EntitlementSnapshot.fromSubscriptionState(
    SubscriptionState state, {
    DateTime? now,
    bool legacyGrandfathered = false,
  }) {
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final expiration = state.expirationDate?.toUtc();
    final hasCanonicalEntitlement = state.entitlementIds.any(
      (id) =>
          id == MonetizationPolicy.canonicalProEntitlementId ||
          MonetizationPolicy.acceptedLegacyEntitlementAliases.contains(id),
    );
    final verifiedLifetime =
        state.verification == SubscriptionVerification.verified &&
        hasCanonicalEntitlement &&
        _isLifetimeProduct(state.productIdentifier);
    final plan =
        legacyGrandfathered || state.isLegacyGrandfathered || verifiedLifetime
        ? PlanKind.legacyGrandfathered
        : state.isPro
        ? PlanKind.pro
        : PlanKind.free;

    if (state.verification == SubscriptionVerification.unavailable) {
      return EntitlementSnapshot(
        plan: plan,
        status: EntitlementStatus.unknown,
        verifiedAt: state.verifiedAt,
      );
    }
    if (plan == PlanKind.legacyGrandfathered) {
      return EntitlementSnapshot(
        plan: plan,
        status: EntitlementStatus.legacyGrandfathered,
        verifiedAt: state.verifiedAt,
      );
    }
    if (state.isPro) {
      return EntitlementSnapshot(
        plan: plan,
        status: switch (state.subscriptionState) {
          PolicySubscriptionState.trial => EntitlementStatus.trial,
          PolicySubscriptionState.gracePeriod => EntitlementStatus.gracePeriod,
          PolicySubscriptionState.billingIssue =>
            EntitlementStatus.billingIssue,
          PolicySubscriptionState.expired => EntitlementStatus.expired,
          PolicySubscriptionState.revoked => EntitlementStatus.revoked,
          _ =>
            expiration != null && !expiration.isAfter(effectiveNow)
                ? EntitlementStatus.expired
                : EntitlementStatus.active,
        },
        verifiedAt: state.verifiedAt,
      );
    }
    return EntitlementSnapshot(
      plan: PlanKind.free,
      status: hasCanonicalEntitlement
          ? EntitlementStatus.revoked
          : EntitlementStatus.free,
      verifiedAt: state.verifiedAt,
    );
  }

  static bool _isLifetimeProduct(String? productIdentifier) {
    final normalized = productIdentifier?.trim() ?? '';
    return MonetizationPolicy.legacyGrandfatheredProductIds.contains(
      normalized,
    );
  }
}

class UsageSnapshot {
  const UsageSnapshot({
    this.used = const {},
    this.allowances = const {},
    this.serverAuthoritative = false,
  });

  const UsageSnapshot.serverAuthoritative()
    : used = const {},
      allowances = const {},
      serverAuthoritative = true;

  final Map<UsageMeterId, int> used;
  final Map<UsageMeterId, int> allowances;
  final bool serverAuthoritative;

  bool isConfigured(UsageMeterId meter) => allowances.containsKey(meter);

  bool hasRemaining(UsageMeterId meter) =>
      isConfigured(meter) && (used[meter] ?? 0) < allowances[meter]!;
}

class ProductValueState {
  const ProductValueState({this.generatedCapabilities = const {}});

  final Set<CapabilityId> generatedCapabilities;

  bool hasGenerated(CapabilityId capability) =>
      generatedCapabilities.contains(capability);
}

/// The only authority for deciding access to monetized capabilities.
abstract final class AccessPolicyEngine {
  static AccessDecision decide({
    required CapabilityId capability,
    required EntitlementSnapshot entitlement,
    UsageSnapshot usage = const UsageSnapshot(),
    ProductValueState productValue = const ProductValueState(),
  }) {
    final policy = MonetizationPolicy.capability(capability);
    if (capability == CapabilityId.readExistingGeneratedOutput) {
      return AccessDecision.allow(AccessDecisionReason.existingGeneratedOutput);
    }
    if (policy.accessClass == AccessClass.userOwned) {
      return AccessDecision.allow(AccessDecisionReason.userOwned);
    }
    if (policy.accessClass == AccessClass.freeProof) {
      if (productValue.hasGenerated(capability)) {
        return AccessDecision.deny(AccessDecisionReason.alreadyGenerated);
      }
      if (policy.usageMeterId == null) {
        return AccessDecision.allow(AccessDecisionReason.freeProofAvailable);
      }
      return _meteredDecision(
        policy,
        usage,
        allowedReason: AccessDecisionReason.freeProofAvailable,
      );
    }
    if (policy.accessClass == AccessClass.pro) {
      return entitlement.hasProAccess
          ? AccessDecision.allow(AccessDecisionReason.proEntitled)
          : AccessDecision.deny(_proDenialReason(entitlement));
    }
    if (policy.accessClass == AccessClass.proMetered) {
      if (!entitlement.hasProAccess) {
        return AccessDecision.deny(_proDenialReason(entitlement));
      }
      return _meteredDecision(
        policy,
        usage,
        allowedReason: AccessDecisionReason.allowanceAvailable,
      );
    }
    return _meteredDecision(
      policy,
      usage,
      allowedReason: AccessDecisionReason.allowanceAvailable,
    );
  }

  static AccessDecision _meteredDecision(
    MonetizationCapability capability,
    UsageSnapshot usage, {
    required AccessDecisionReason allowedReason,
  }) {
    if (usage.serverAuthoritative) {
      return AccessDecision.allow(allowedReason);
    }
    final meter = capability.usageMeterId!;
    if (!usage.isConfigured(meter)) {
      return AccessDecision.deny(AccessDecisionReason.allowanceNotConfigured);
    }
    if (!usage.hasRemaining(meter)) {
      return AccessDecision.deny(AccessDecisionReason.allowanceExhausted);
    }
    return AccessDecision.allow(allowedReason);
  }

  static AccessDecisionReason _proDenialReason(
    EntitlementSnapshot entitlement,
  ) => entitlement.status == EntitlementStatus.unknown
      ? AccessDecisionReason.entitlementUnknown
      : AccessDecisionReason.proRequired;
}
