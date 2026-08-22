import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for first-use wording helper — prompt type only, never text.
abstract final class FirstUseWordingAnalytics {
  FirstUseWordingAnalytics._();

  static const selectedEvent = 'first_use_wording_helper_selected';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void selected({required String source, required String promptType}) {
    final props = <String, Object>{'source': source, 'prompt_type': promptType};
    captureForTest?.call(selectedEvent, props);
    ActivationFunnelAnalytics.track(
      selectedEvent,
      source: source,
      promptType: promptType,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_FIRST_USE_WORDING event=$selectedEvent source=$source '
        'prompt_type=$promptType',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}