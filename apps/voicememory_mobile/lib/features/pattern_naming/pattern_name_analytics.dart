import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for pattern name confirmation — metadata only.
abstract final class PatternNameAnalytics {
  PatternNameAnalytics._();

  static const promptSeenEvent = 'pattern_name_prompt_seen';
  static const confirmedEvent = 'pattern_name_confirmed';
  static const renamedEvent = 'pattern_name_renamed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void promptSeen({
    required String source,
    required int entryCount,
    required bool hasCustomName,
  }) {
    _emit(
      promptSeenEvent,
      source: source,
      entryCount: entryCount,
      hasCustomName: hasCustomName,
    );
  }

  static void confirmed({
    required String source,
    required int entryCount,
    required bool hasCustomName,
  }) {
    _emit(
      confirmedEvent,
      source: source,
      entryCount: entryCount,
      hasCustomName: hasCustomName,
    );
  }

  static void renamed({
    required String source,
    required int entryCount,
    required bool hasCustomName,
  }) {
    _emit(
      renamedEvent,
      source: source,
      entryCount: entryCount,
      hasCustomName: hasCustomName,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasCustomName,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_custom_name': hasCustomName ? 1 : 0,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasCustomName: hasCustomName,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PATTERN_NAME event=$event source=$source '
        'entry_count=$entryCount has_custom_name=$hasCustomName',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
