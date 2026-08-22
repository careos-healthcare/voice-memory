import 'package:archiveme_mobile/features/activation/events/activation_event_counts_deferred.dart' show ActivationEventCountsDeferred;
import 'package:archiveme_mobile/features/activation/events/v1_event_registry.dart' show V1EventRegistry;

/// Tier 4 — funnel and monetization analytics (deferred from consumer V1).
///
/// These event families must not ship in [V1EventRegistry]. They remain
/// available for internal QA export via [ActivationEventCountsDeferred].
abstract final class Tier4FunnelEvents {
  Tier4FunnelEvents._();

  static const capacityPullReasonPrefix = 'capacity_pull_reason_';
  static const pressureProUpgradeCard = 'pressure_pro_upgrade_card';
  static const paywallTriggerShown = 'paywallTriggerShown';

  static const List<String> examples = [
    capacityPullReasonPrefix,
    pressureProUpgradeCard,
    paywallTriggerShown,
    'retentionPrimaryCtaTapped',
    'retentionStateShown',
    'patternMapOpened',
  ];
}