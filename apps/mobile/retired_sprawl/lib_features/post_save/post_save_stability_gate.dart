import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Gates expensive archive / memory card generation immediately after save so
/// the success UI can settle before heavy engines run.
abstract class PostSaveStabilityGate {
  PostSaveStabilityGate._();

  /// Compile-time kill switch:
  /// `--dart-define=ARCHIVEME_DISABLE_POST_SAVE_ARCHIVE_CARDS=true`
  static const disableArchiveCards = bool.fromEnvironment(
    'ARCHIVEME_DISABLE_POST_SAVE_ARCHIVE_CARDS',
  );

  /// First N entries use the simple post-save surface only.
  static const int simpleUiMaxEntryCount = 2;

  static bool shouldSkipArchiveCards({required int entryCount}) =>
      disableArchiveCards || entryCount <= simpleUiMaxEntryCount;

  static void logGate({required bool enabled, required int entryCount}) {
    AppLogger.debug(
      'ARCHIVEME_POST_SAVE_STABILITY_GATE enabled=$enabled entryCount=$entryCount',
    );
  }

  static void logSkipped({String reason = 'first_entries_or_debug_gate'}) {
    AppLogger.debug('ARCHIVEME_POST_SAVE_ARCHIVE_CARDS_SKIPPED reason=$reason');
  }

  static void logStarted() {
    AppLogger.debug('ARCHIVEME_POST_SAVE_ARCHIVE_CARDS_STARTED');
  }

  static void logCompleted() {
    AppLogger.debug('ARCHIVEME_POST_SAVE_ARCHIVE_CARDS_COMPLETED');
  }

  static void logFailed(Object reason) {
    AppLogger.debug('ARCHIVEME_POST_SAVE_ARCHIVE_CARDS_FAILED reason=$reason');
  }
}