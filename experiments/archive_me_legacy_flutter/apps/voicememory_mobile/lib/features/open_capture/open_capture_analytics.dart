import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'open_capture_model.dart';

/// Safe analytics for open capture chips — metadata only.
abstract final class OpenCaptureAnalytics {
  OpenCaptureAnalytics._();

  static const seenEvent = 'open_capture_seen';
  static const chipTappedEvent = 'open_capture_chip_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required String source, required int entryCount}) {
    _emit(seenEvent, source: source, entryCount: entryCount, chipType: null);
  }

  static void chipTapped({
    required String source,
    required int entryCount,
    required OpenCaptureChipType chipType,
  }) {
    _emit(
      chipTappedEvent,
      source: source,
      entryCount: entryCount,
      chipType: chipType,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required OpenCaptureChipType? chipType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      if (chipType != null) 'chip_type': chipType.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_OPEN_CAPTURE event=$event source=$source '
        'entry_count=$entryCount chip_type=${chipType?.analyticsValue ?? 'none'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
