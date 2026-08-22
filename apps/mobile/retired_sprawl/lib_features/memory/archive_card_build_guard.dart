import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Defensive wrapper for memory / archive insight cards.
abstract class ArchiveCardBuildGuard {
  ArchiveCardBuildGuard._();

  static Widget build({
    required String card,
    required Widget Function() builder,
  }) {
    try {
      return builder();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        AppLogger.debug('ARCHIVEME_ARCHIVE_CARD_BUILD_FAILED card=$card error=$e');
        AppLogger.debug('$stackTrace');
      }
      return const SizedBox.shrink();
    }
  }

  /// Safe synchronous engine/card-model builder — never throws to callers.
  static T runEngine<T>({
    required String card,
    required T Function() builder,
    required T fallback,
  }) {
    try {
      return builder();
    } catch (e, stackTrace) {
      AppLogger.debug(
        'ARCHIVEME_POST_SAVE_ARCHIVE_CARDS_FAILED card=$card reason=$e',
      );
      if (kDebugMode) {
        AppLogger.debug('$stackTrace');
      }
      return fallback;
    }
  }
}