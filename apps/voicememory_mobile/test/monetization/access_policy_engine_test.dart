import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

void main() {
  const entitlementStates = <EntitlementSnapshot>[
    EntitlementSnapshot.free(),
    EntitlementSnapshot(plan: PlanKind.pro, status: EntitlementStatus.active),
    EntitlementSnapshot(plan: PlanKind.pro, status: EntitlementStatus.trial),
    EntitlementSnapshot(
      plan: PlanKind.pro,
      status: EntitlementStatus.gracePeriod,
    ),
    EntitlementSnapshot(
      plan: PlanKind.pro,
      status: EntitlementStatus.billingIssue,
    ),
    EntitlementSnapshot(plan: PlanKind.pro, status: EntitlementStatus.expired),
    EntitlementSnapshot(plan: PlanKind.free, status: EntitlementStatus.revoked),
    EntitlementSnapshot.unknown(),
  ];
  const archiveSizes = [1, 3, 7, 50, 1000000];

  group('user-owned access matrix', () {
    final userOwned = CapabilityId.values.where(
      (id) =>
          MonetizationPolicy.capability(id).accessClass ==
          AccessClass.userOwned,
    );

    for (final entitlement in entitlementStates) {
      for (final archiveSize in archiveSizes) {
        test(
          '${entitlement.status.name} allows originals at $archiveSize entries',
          () {
            for (final capability in userOwned) {
              final decision = AccessPolicyEngine.decide(
                capability: capability,
                entitlement: entitlement,
              );
              expect(
                decision.allowed,
                isTrue,
                reason:
                    '${capability.name} must ignore entitlement and archive size',
              );
              expect(
                decision.reason,
                capability == CapabilityId.readExistingGeneratedOutput
                    ? AccessDecisionReason.existingGeneratedOutput
                    : AccessDecisionReason.userOwned,
              );
            }
          },
        );
      }
    }
  });

  test('existing generated output remains readable after loss of access', () {
    for (final entitlement in entitlementStates) {
      expect(
        AccessPolicyEngine.decide(
          capability: CapabilityId.readExistingGeneratedOutput,
          entitlement: entitlement,
        ).allowed,
        isTrue,
      );
    }
  });

  group('free proof', () {
    test('first observation and comparison are available once offline', () {
      for (final entitlement in entitlementStates) {
        expect(
          AccessPolicyEngine.decide(
            capability: CapabilityId.firstEvidenceObservation,
            entitlement: entitlement,
          ).allowed,
          isTrue,
        );
        expect(
          AccessPolicyEngine.decide(
            capability: CapabilityId.firstEarlyComparison,
            entitlement: entitlement,
          ).allowed,
          isTrue,
        );
      }
    });

    test('only a successfully generated proof consumes the free value', () {
      expect(
        AccessPolicyEngine.decide(
          capability: CapabilityId.firstEvidenceObservation,
          entitlement: const EntitlementSnapshot.free(),
          productValue: const ProductValueState(
            generatedCapabilities: {CapabilityId.firstEvidenceObservation},
          ),
        ).reason,
        AccessDecisionReason.alreadyGenerated,
      );
    });

    test('remote observation remains server-metered', () {
      expect(
        AccessPolicyEngine.decide(
          capability: CapabilityId.remoteObservationGeneration,
          entitlement: const EntitlementSnapshot.free(),
        ).reason,
        AccessDecisionReason.allowanceNotConfigured,
      );
    });
  });

  test('ongoing generation requires active Pro and configured allowance', () {
    const capability = CapabilityId.ongoingComparisons;
    const configured = UsageSnapshot(
      allowances: {UsageMeterId.ongoingComparisonGeneration: 1},
    );
    for (final entitlement in entitlementStates) {
      final decision = AccessPolicyEngine.decide(
        capability: capability,
        entitlement: entitlement,
        usage: configured,
      );
      expect(decision.allowed, entitlement.hasProAccess);
    }
    expect(
      AccessPolicyEngine.decide(
        capability: capability,
        entitlement: const EntitlementSnapshot(
          plan: PlanKind.pro,
          status: EntitlementStatus.active,
        ),
      ).reason,
      AccessDecisionReason.allowanceNotConfigured,
    );
  });

  test('access decisions expose stable product-facing decision kinds', () {
    expect(
      AccessPolicyEngine.decide(
        capability: CapabilityId.firstEvidenceObservation,
        entitlement: const EntitlementSnapshot.unknown(),
      ).kind,
      AccessDecisionKind.allowedAsFreeProof,
    );
    expect(
      AccessPolicyEngine.decide(
        capability: CapabilityId.readExistingGeneratedOutput,
        entitlement: const EntitlementSnapshot(
          plan: PlanKind.pro,
          status: EntitlementStatus.expired,
        ),
      ).kind,
      AccessDecisionKind.allowedReadOnly,
    );
    expect(
      AccessPolicyEngine.decide(
        capability: CapabilityId.ongoingComparisons,
        entitlement: const EntitlementSnapshot.free(),
      ).kind,
      AccessDecisionKind.requiresPro,
    );
    expect(
      AccessPolicyEngine.decide(
        capability: CapabilityId.remoteTranscription,
        entitlement: const EntitlementSnapshot.free(),
      ).kind,
      AccessDecisionKind.configurationMissing,
    );
  });

  test('client preflight delegates only usage to the authoritative server', () {
    final pro = AccessPolicyEngine.decide(
      capability: CapabilityId.deepArchiveSynthesis,
      entitlement: const EntitlementSnapshot(
        plan: PlanKind.pro,
        status: EntitlementStatus.active,
      ),
      usage: const UsageSnapshot.serverAuthoritative(),
    );
    final free = AccessPolicyEngine.decide(
      capability: CapabilityId.deepArchiveSynthesis,
      entitlement: const EntitlementSnapshot.free(),
      usage: const UsageSnapshot.serverAuthoritative(),
    );

    expect(pro.allowed, isTrue);
    expect(free.kind, AccessDecisionKind.requiresPro);
  });

  group('SubscriptionState mapping', () {
    final now = DateTime.utc(2026, 8, 1);

    test('maps active, expired, revoked, and unknown explicitly', () {
      SubscriptionState state({
        required SubscriptionTier tier,
        required SubscriptionVerification verification,
        List<String> ids = const [],
        DateTime? expiration,
      }) => SubscriptionState(
        tier: tier,
        entitlementIds: ids,
        billingConnected: true,
        origin: SubscriptionStateOrigin.store,
        verification: verification,
        expirationDate: expiration,
      );

      expect(
        EntitlementSnapshot.fromSubscriptionState(
          state(
            tier: SubscriptionTier.pro,
            verification: SubscriptionVerification.verified,
            ids: const ['archive_loop_pro'],
            expiration: now.add(const Duration(days: 1)),
          ),
          now: now,
        ).status,
        EntitlementStatus.active,
      );
      expect(
        EntitlementSnapshot.fromSubscriptionState(
          state(
            tier: SubscriptionTier.pro,
            verification: SubscriptionVerification.verified,
            ids: const ['archive_loop_pro'],
            expiration: now,
          ),
          now: now,
        ).status,
        EntitlementStatus.expired,
      );
      expect(
        EntitlementSnapshot.fromSubscriptionState(
          state(
            tier: SubscriptionTier.free,
            verification: SubscriptionVerification.verified,
            ids: const ['archive_loop_pro'],
          ),
          now: now,
        ).status,
        EntitlementStatus.revoked,
      );
      expect(
        EntitlementSnapshot.fromSubscriptionState(
          state(
            tier: SubscriptionTier.free,
            verification: SubscriptionVerification.unavailable,
          ),
          now: now,
        ).status,
        EntitlementStatus.unknown,
      );
    });
  });
}
