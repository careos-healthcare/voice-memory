import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'first_moment_capture_model.dart';

/// Safe metadata analytics for first moment capture — no journal text.
abstract final class FirstMomentCaptureAnalytics {
  FirstMomentCaptureAnalytics._();

  static const seenEvent = 'first_moment_capture_seen';
  static const ctaTappedEvent = 'first_moment_capture_cta_tapped';
  static const exampleTappedEvent = 'first_moment_capture_example_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required FirstMomentCaptureResult result}) {
    _emit(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
      actionType: null,
      exampleType: null,
    );
  }

  static void ctaTapped({
    required FirstMomentCaptureResult result,
    required FirstMomentCaptureActionType actionType,
  }) {
    _emit(
      ctaTappedEvent,
      source: result.source,
      entryCount: result.entryCount,
      actionType: actionType,
      exampleType: null,
    );
  }

  static void exampleTapped({
    required FirstMomentCaptureResult result,
    required FirstMomentCaptureExampleType exampleType,
  }) {
    _emit(
      exampleTappedEvent,
      source: result.source,
      entryCount: result.entryCount,
      actionType: null,
      exampleType: exampleType,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required FirstMomentCaptureActionType? actionType,
    required FirstMomentCaptureExampleType? exampleType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      if (actionType != null) 'action_type': actionType.name,
      if (exampleType != null) 'example_type': exampleType.name,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_FIRST_MOMENT_CAPTURE event=$event source=$source '
        'entry_count=$entryCount action_type=${actionType?.name} '
        'example_type=${exampleType?.name}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
