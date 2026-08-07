import 'package:flutter/foundation.dart';

import '../../features/revenue_metrics/revenue_funnel_analytics.dart';
import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the Pro evidence value bridge.
abstract final class ProEvidenceValueAnalytics {
  ProEvidenceValueAnalytics._();

  static const seenEvent = 'pro_evidence_value_seen';
  static const ctaTappedEvent = 'pro_evidence_value_cta_tapped';
  static const dismissedEvent = 'pro_evidence_value_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required String source, required int entryCount}) {
    _emit(seenEvent, source: source, entryCount: entryCount);
  }

  static void ctaTapped({
    required String source,
    required int entryCount,
    required String actionType,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      entryCount: entryCount,
      actionType: actionType,
    );
  }

  static void dismissed({required String source, required int entryCount}) {
    _emit(dismissedEvent, source: source, entryCount: entryCount);
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    String? actionType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'action_type': ?actionType,
    };

    captureForTest?.call(event, props);
    if (event == seenEvent) {
      RevenueFunnelAnalytics.proEvidenceValueSeen(
        source: source,
        entryCount: entryCount,
      );
    } else if (event == ctaTappedEvent) {
      RevenueFunnelAnalytics.proEvidenceValueCtaTapped(
        source: source,
        entryCount: entryCount,
      );
    }
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      actionType: actionType,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRO_EVIDENCE_VALUE event=$event source=$source '
        'entry_count=$entryCount '
        '${actionType != null ? 'action_type=$actionType' : ''}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
