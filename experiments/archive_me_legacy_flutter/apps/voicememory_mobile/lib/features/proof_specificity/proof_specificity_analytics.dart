import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'proof_specificity_model.dart';

/// Safe analytics for proof specificity — metadata only.
abstract final class ProofSpecificityAnalytics {
  ProofSpecificityAnalytics._();

  static const seenEvent = 'proof_specificity_seen';
  static const captureFreedomSeenEvent = 'capture_freedom_line_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required ProofSpecificityResult result,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      hasBeliefSurface: result.hasBeliefSurface,
      evidenceAnchorCount: result.evidenceAnchorCount,
    );
  }

  static void captureFreedomSeen({
    required String source,
    required int entryCount,
  }) {
    _emit(
      captureFreedomSeenEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: false,
      hasBeliefSurface: false,
      evidenceAnchorCount: 0,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasBeliefSurface,
    required int evidenceAnchorCount,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'has_belief_surface': hasBeliefSurface ? 1 : 0,
      'evidence_anchor_count': evidenceAnchorCount,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_SPECIFICITY event=$event source=$source '
        'entry_count=$entryCount has_confirmed_repeat=$hasConfirmedRepeat '
        'has_belief_surface=$hasBeliefSurface '
        'evidence_anchor_count=$evidenceAnchorCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
