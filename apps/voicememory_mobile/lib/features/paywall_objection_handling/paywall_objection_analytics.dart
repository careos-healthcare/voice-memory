import 'package:flutter/foundation.dart';

import '../../billing/paywall_source.dart';
import '../../services/activation_funnel_analytics.dart';
import 'paywall_objection_copy.dart';
import 'paywall_objection_model.dart';

/// Metadata-only analytics for paywall objection handling.
abstract final class PaywallObjectionAnalytics {
  PaywallObjectionAnalytics._();

  static const seenEvent = 'paywall_objection_section_seen';
  static const expandedEvent = 'paywall_objection_expanded';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void sectionSeen({
    required String source,
    required String surface,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      surfaceType: surface,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PAYWALL_OBJECTION event=$seenEvent source=$source surface=$surface',
      );
    }
  }

  static void expanded({
    required String source,
    required String surface,
    required PaywallObjectionId objectionId,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'objection_id': objectionId.analyticsValue,
    };
    captureForTest?.call(expandedEvent, props);
    ActivationFunnelAnalytics.track(
      expandedEvent,
      source: source,
      surfaceType: surface,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PAYWALL_OBJECTION event=$expandedEvent source=$source '
        'surface=$surface objection_id=${objectionId.analyticsValue}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
