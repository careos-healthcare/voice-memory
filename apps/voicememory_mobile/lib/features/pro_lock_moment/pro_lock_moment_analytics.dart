import 'package:flutter/foundation.dart';

import '../../features/revenue_metrics/revenue_funnel_analytics.dart';
import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the Pro lock moment.
abstract final class ProLockMomentAnalytics {
  ProLockMomentAnalytics._();

  static const seenEvent = 'pro_lock_moment_seen';
  static const ctaTappedEvent = 'pro_lock_moment_cta_tapped';
  static const dismissedEvent = 'pro_lock_moment_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool hasFirstProof,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      hasFirstProof: hasFirstProof,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void ctaTapped({
    required String source,
    required int entryCount,
    required bool hasFirstProof,
    required bool hasConfirmedRepeat,
    required String actionType,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      entryCount: entryCount,
      hasFirstProof: hasFirstProof,
      hasConfirmedRepeat: hasConfirmedRepeat,
      actionType: actionType,
    );
  }

  static void dismissed({
    required String source,
    required int entryCount,
    required bool hasFirstProof,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      dismissedEvent,
      source: source,
      entryCount: entryCount,
      hasFirstProof: hasFirstProof,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasFirstProof,
    required bool hasConfirmedRepeat,
    String? actionType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_first_proof': hasFirstProof ? 1 : 0,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      if (actionType != null) 'action_type': actionType,
    };

    captureForTest?.call(event, props);
    if (event == seenEvent) {
      RevenueFunnelAnalytics.proLockSeen(
        source: source,
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
      );
    } else if (event == ctaTappedEvent) {
      RevenueFunnelAnalytics.proLockCtaTapped(
        source: source,
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
      );
    }
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRO_LOCK_MOMENT event=$event source=$source '
        'entry_count=$entryCount has_first_proof=${props['has_first_proof']} '
        'has_confirmed_repeat=${props['has_confirmed_repeat']}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
