import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Step markers for the ArchiveLens return-hook full user loop (debug / QA).
abstract class ArchiveFullLoopLog {
  ArchiveFullLoopLog._();

  static void step(String step) {
    AppLogger.debug('ARCHIVEME_FULL_LOOP_STEP step=$step');
  }
}