import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for helped tracking — metadata only, no user text.
abstract final class HelpedTrackingAnalytics {
  HelpedTrackingAnalytics._();

  static const promptSeenEvent = 'helped_prompt_seen';
  static const optionSelectedEvent = 'helped_option_selected';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void promptSeen({required String source, required int entryCount}) {
    _emit(
      promptSeenEvent,
      source: source,
      entryCount: entryCount,
      optionType: null,
      hasFreeText: false,
    );
  }

  static void optionSelected({
    required String source,
    required int entryCount,
    required HelpedTrackingOption option,
    required bool hasFreeText,
  }) {
    _emit(
      optionSelectedEvent,
      source: source,
      entryCount: entryCount,
      optionType: option.analyticsValue,
      hasFreeText: hasFreeText,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required String? optionType,
    required bool hasFreeText,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_free_text': hasFreeText ? 1 : 0,
      'option_type': ?optionType,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      optionType: optionType,
      hasFreeText: hasFreeText,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_HELPED_TRACKING event=$event source=$source '
        'entry_count=$entryCount option_type=$optionType '
        'has_free_text=$hasFreeText',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}