import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the beta invite loop card.
abstract final class BetaInviteAnalytics {
  BetaInviteAnalytics._();

  static const seenEvent = 'beta_invite_seen';
  static const copiedEvent = 'beta_invite_copied';
  static const dismissedEvent = 'beta_invite_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required String surface,
    required int entryCount,
    required String trigger,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      trigger: trigger,
    );
  }

  static void copied({
    required String source,
    required String surface,
    required int entryCount,
    required String trigger,
  }) {
    _emit(
      copiedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      trigger: trigger,
    );
  }

  static void dismissed({
    required String source,
    required String surface,
    required int entryCount,
    required String trigger,
  }) {
    _emit(
      dismissedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      trigger: trigger,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required String surface,
    required int entryCount,
    required String trigger,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'entry_count': entryCount,
      'trigger': trigger,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      surfaceType: surface,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_INVITE event=$event source=$source surface=$surface '
        'entry_count=$entryCount trigger=$trigger',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
