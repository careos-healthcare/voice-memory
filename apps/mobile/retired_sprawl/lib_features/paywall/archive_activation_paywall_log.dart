import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Step markers for the archive loop activation-to-paywall journey (debug / QA).
abstract class ArchiveActivationPaywallLog {
  ArchiveActivationPaywallLog._();

  static void step(String step) {
    AppLogger.debug('ARCHIVEME_ACTIVATION_PAYWALL_STEP step=$step');
  }
}