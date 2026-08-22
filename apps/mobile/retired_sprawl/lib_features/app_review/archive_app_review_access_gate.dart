import 'package:flutter/foundation.dart';

/// Gates App Store review access UI — compile-time only via dart-define.
abstract class ArchiveAppReviewAccessGate {
  ArchiveAppReviewAccessGate._();

  static const reviewCode = 'ARCHIVEME-REVIEW-2026';

  @visibleForTesting
  static bool? enabledOverride;

  static const _appReviewModeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_APP_REVIEW_MODE',
  );

  static bool get isEnabled {
    if (enabledOverride != null) return enabledOverride!;
    return _appReviewModeFromEnvironment;
  }

  @visibleForTesting
  static void resetForTest() {
    enabledOverride = null;
  }
}