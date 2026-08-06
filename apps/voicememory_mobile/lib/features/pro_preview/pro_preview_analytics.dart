import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for Pro preview cards.
abstract final class ProPreviewAnalytics {
  ProPreviewAnalytics._();

  static const seenEvent = 'pro_preview_seen';
  static const ctaTappedEvent = 'pro_preview_cta_tapped';
  static const dismissedEvent = 'pro_preview_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required String surface,
    required int entryCount,
    required bool hasTimelineProof,
    required bool hasFirstProof,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      hasTimelineProof: hasTimelineProof,
      hasFirstProof: hasFirstProof,
    );
  }

  static void ctaTapped({
    required String source,
    required String surface,
    required int entryCount,
    required bool hasTimelineProof,
    required bool hasFirstProof,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      hasTimelineProof: hasTimelineProof,
      hasFirstProof: hasFirstProof,
    );
  }

  static void dismissed({
    required String source,
    required String surface,
    required int entryCount,
    required bool hasTimelineProof,
    required bool hasFirstProof,
  }) {
    _emit(
      dismissedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      hasTimelineProof: hasTimelineProof,
      hasFirstProof: hasFirstProof,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required String surface,
    required int entryCount,
    required bool hasTimelineProof,
    required bool hasFirstProof,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'entry_count': entryCount,
      'has_timeline_proof': hasTimelineProof ? 1 : 0,
      'has_first_proof': hasFirstProof ? 1 : 0,
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
        'ARCHIVEME_PRO_PREVIEW event=$event source=$source surface=$surface '
        'entry_count=$entryCount has_timeline_proof=$hasTimelineProof '
        'has_first_proof=$hasFirstProof',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
