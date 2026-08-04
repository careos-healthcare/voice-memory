import '../../../storage/mobile_prefs_store.dart';
import '../../../subscriptions/domain/subscription_models.dart';
import '../domain/access_policy_engine.dart';
import '../domain/product_value_delivery_ledger.dart';
import 'product_value_delivery_recorder.dart';

class MonetizationMigrationResult {
  const MonetizationMigrationResult({
    required this.legacyGrandfathered,
    required this.productValue,
  });

  final bool legacyGrandfathered;
  final ProductValueState productValue;
}

/// User-favourable, idempotent migration into the canonical policy state.
///
/// It only adds evidence of already generated outputs and only records lifetime
/// access when a verified store/backend state identifies a lifetime product.
/// Legacy request counters are deliberately ignored so they cannot consume the
/// new first-observation or first-comparison proof.
///
/// The two free-proof capabilities are deliberately absent from this store.
/// Generating an observation is not the same as delivering one, so only the
/// [ProductValueDeliveryLedger] — which requires the artifact to have reached
/// the user — can report them as spent.
class MonetizationLocalMigration {
  const MonetizationLocalMigration(this._prefs);

  static const String storageKey = 'monetizationPolicyStateV1';
  static const int version = 1;

  final MobilePrefsStore _prefs;

  Future<MonetizationMigrationResult> run({
    required SubscriptionState subscription,
    Set<CapabilityId> discoveredGeneratedOutputs = const {},
    ProductValueDeliveryLedger? deliveredProof,
  }) async {
    final delivered =
        deliveredProof ?? await ProductValueDeliveryRecorder.ensureLoaded();
    final snapshot = EntitlementSnapshot.fromSubscriptionState(subscription);
    final verifiedLifetime =
        snapshot.plan == PlanKind.legacyGrandfathered &&
        snapshot.status == EntitlementStatus.legacyGrandfathered;
    final stored = await _prefs.updateMap(storageKey, (current) {
      final existingGenerated = _parseCapabilities(
        current?['generatedCapabilities'],
      );
      final generated = {
        ...existingGenerated,
        ...discoveredGeneratedOutputs.where(_isGeneratedOutputCapability),
      };
      return {
        'version': version,
        'policyVersion': MonetizationPolicy.policyVersion,
        // Never downgrade a previously verified lifetime migration.
        'legacyGrandfathered':
            current?['legacyGrandfathered'] == true || verifiedLifetime,
        'generatedCapabilities': generated.map((id) => id.name).toList()
          ..sort(),
      };
    });
    return MonetizationMigrationResult(
      legacyGrandfathered: stored['legacyGrandfathered'] == true,
      productValue: ProductValueState(
        generatedCapabilities: {
          ..._parseCapabilities(stored['generatedCapabilities']),
          ...delivered.productValue.generatedCapabilities,
        },
      ),
    );
  }

  static bool _isGeneratedOutputCapability(CapabilityId capability) =>
      capability == CapabilityId.ongoingComparisons ||
      capability == CapabilityId.fullChangesHistoryGeneration ||
      capability == CapabilityId.deepArchiveSynthesis ||
      capability == CapabilityId.fullHistoryQuestion ||
      capability == CapabilityId.periodicReviewGeneration;

  static Set<CapabilityId> _parseCapabilities(Object? raw) {
    if (raw is! List) return {};
    return raw
        .map((value) => value.toString())
        .map(
          (name) => CapabilityId.values
              .where((capability) => capability.name == name)
              .firstOrNull,
        )
        .whereType<CapabilityId>()
        .where(_isGeneratedOutputCapability)
        .toSet();
  }
}
