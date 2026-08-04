import 'package:flutter/foundation.dart';

/// Step markers for the archive loop activation-to-paywall journey (debug / QA).
abstract class ArchiveActivationPaywallLog {
  ArchiveActivationPaywallLog._();

  static void step(String step) {
    debugPrint('ARCHIVEME_ACTIVATION_PAYWALL_STEP step=$step');
  }
}
