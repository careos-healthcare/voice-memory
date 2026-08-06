import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'correction_memory_model.dart';

/// Safe analytics for archive corrections — metadata only.
abstract final class CorrectionMemoryAnalytics {
  CorrectionMemoryAnalytics._();

  static const savedEvent = 'correction_memory_saved';
  static const seenEvent = 'correction_memory_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void saved({
    required String source,
    required CorrectionMemoryResult result,
  }) {
    _emit(
      savedEvent,
      source: source,
      entryCount: result.entryCount,
      correctionState: result.state,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
  }

  static void seen({
    required String source,
    required CorrectionMemoryResult result,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: result.entryCount,
      correctionState: result.state,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required CorrectionMemoryState correctionState,
    required bool hasConfirmedRepeat,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'correction_state': correctionState.analyticsValue,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
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
        'ARCHIVEME_CORRECTION_MEMORY event=$event source=$source '
        'entry_count=$entryCount correction_state=${correctionState.analyticsValue} '
        'has_confirmed_repeat=$hasConfirmedRepeat',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
