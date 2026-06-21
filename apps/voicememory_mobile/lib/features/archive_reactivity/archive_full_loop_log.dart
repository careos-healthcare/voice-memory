import 'package:flutter/foundation.dart';

/// Step markers for the ArchiveLens return-hook full user loop (debug / QA).
abstract class ArchiveFullLoopLog {
  ArchiveFullLoopLog._();

  static void step(String step) {
    debugPrint('ARCHIVEME_FULL_LOOP_STEP step=$step');
  }
}
