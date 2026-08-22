import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Lightweight on-device analytics — metadata events only, no remote PII.
abstract class AnalyticsService {
  void logEvent(String name, Map<String, Object> parameters);
}

/// Default sink: debug log in development builds.
class LocalAnalyticsService implements AnalyticsService {
  @override
  void logEvent(String name, Map<String, Object> parameters) {
    if (kDebugMode) {
      AppLogger.debug('ANALYTICS event=$name $parameters');
    }
  }
}

/// Global analytics accessor — override in widget tests via [testOverride].
abstract final class AnalyticsServices {
  AnalyticsServices._();

  static AnalyticsService _production = LocalAnalyticsService();

  @visibleForTesting
  static AnalyticsService? testOverride;

  static AnalyticsService get instance => testOverride ?? _production;

  @visibleForTesting
  static void resetForTest() {
    testOverride = null;
  }
}
