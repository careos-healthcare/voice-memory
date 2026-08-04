import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/monetization/domain/focused_return_access_policy.dart';

void main() {
  test('existing generated results remain readable without Pro', () {
    final decision = FocusedReturnAccessPolicy.readExisting(
      entitlement: const EntitlementSnapshot.free(),
    );

    expect(decision.allowed, isTrue);
    expect(decision.reason, AccessDecisionReason.userOwned);
  });

  test('one and two moments use the two free-proof capabilities', () {
    expect(
      FocusedReturnAccessPolicy.generationCapability(1),
      CapabilityId.firstEvidenceObservation,
    );
    expect(
      FocusedReturnAccessPolicy.generationCapability(2),
      CapabilityId.firstEarlyComparison,
    );
  });

  test('ongoing comparisons require Pro and an allowance', () {
    final usage = UsageSnapshot(
      allowances: {UsageMeterId.ongoingComparisonGeneration: 1},
    );
    final free = FocusedReturnAccessPolicy.generate(
      distinctMomentCount: 3,
      entitlement: const EntitlementSnapshot.free(),
      usage: usage,
    );
    final pro = FocusedReturnAccessPolicy.generate(
      distinctMomentCount: 3,
      entitlement: const EntitlementSnapshot(
        plan: PlanKind.pro,
        status: EntitlementStatus.active,
      ),
      usage: usage,
    );

    expect(free.allowed, isFalse);
    expect(free.reason, AccessDecisionReason.proRequired);
    expect(pro.allowed, isTrue);
    expect(pro.reason, AccessDecisionReason.allowanceAvailable);
  });
}
