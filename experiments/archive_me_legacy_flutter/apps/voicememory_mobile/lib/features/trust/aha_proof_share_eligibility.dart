import 'package:flutter/foundation.dart';

/// Session eligibility for the aha proof share card — after useful aha
/// feedback only. No auto-share; compile-time share text only.
abstract class AhaProofShareEligibility {
  AhaProofShareEligibility._();

  static var _eligible = false;
  static var _shownThisSession = false;
  static var _dismissedThisSession = false;

  static void markEligibleFromAhaUseful() => _eligible = true;

  static bool get shouldShow =>
      _eligible && !_shownThisSession && !_dismissedThisSession;

  static void markShown() => _shownThisSession = true;

  static void dismiss() {
    _dismissedThisSession = true;
    _shownThisSession = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _eligible = false;
    _shownThisSession = false;
    _dismissedThisSession = false;
  }
}
