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
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ARCHIVEME_ARCHIVE_CARD_BUILD_FAILED card=$card error=$e');
        debugPrint('$st');
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
    } catch (e, st) {
      debugPrint(
        'ARCHIVEME_POST_SAVE_ARCHIVE_CARDS_FAILED card=$card reason=$e',
      );
      if (kDebugMode) {
        debugPrint('$st');
      }
      return fallback;
    }
  }
}
