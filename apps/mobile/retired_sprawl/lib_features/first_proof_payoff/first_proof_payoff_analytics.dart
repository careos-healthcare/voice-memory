import 'dart:async';

import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:archiveme_mobile/features/revenue_metrics/revenue_funnel_analytics.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';

/// Safe metadata analytics for first proof payoff — no journal text.
abstract final class FirstProofPayoffAnalytics {
  FirstProofPayoffAnalytics._();

  static const seenEvent = 'first_proof_payoff_seen';
  static const ctaTappedEvent = 'first_proof_payoff_cta_tapped';

  static void seen({
    required int entryCount,
    required bool hasSnippets,
    required bool hasPatternDetailCta,
    String source = 'record',
  }) {
    ActivationFunnelAnalytics.track(
      seenEvent,
      entryCount: entryCount,
      source: source,
      hasSnippets: hasSnippets,
      hasPatternDetailCta: hasPatternDetailCta,
      oncePerSession: true,
      stage: 'first_proof_payoff',
    );
    RevenueFunnelAnalytics.firstProofSeen(
      entryCount: entryCount,
      source: source,
    );
    unawaited(DelayedPaywallProofStore.markFirstRepeatSeen());
  }

  static void ctaTapped({
    required int entryCount,
    required bool hasSnippets,
    required bool hasPatternDetailCta,
    required String cta,
    String source = 'record',
  }) {
    ActivationFunnelAnalytics.track(
      ctaTappedEvent,
      entryCount: entryCount,
      source: source,
      hasSnippets: hasSnippets,
      hasPatternDetailCta: hasPatternDetailCta,
      stage: cta,
    );
  }
}