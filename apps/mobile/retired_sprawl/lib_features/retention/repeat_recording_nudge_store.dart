import 'package:flutter/foundation.dart';

/// Session-scoped seen/dismiss state for repeat-recording nudges.
///
/// "Once per session" is enforced here — nothing persists across app restarts.
class RepeatRecordingNudgeSession {
  RepeatRecordingNudgeSession._();

  static var _secondEntryShown = false;
  static var _secondEntryDismissed = false;
  static var _day2Shown = false;
  static var _day2Dismissed = false;

  static bool get secondEntryHidden =>
      _secondEntryShown || _secondEntryDismissed;

  static bool get day2Hidden => _day2Shown || _day2Dismissed;

  static void markSecondEntryShown() => _secondEntryShown = true;

  static void dismissSecondEntry() {
    _secondEntryDismissed = true;
    _secondEntryShown = true;
  }

  static void markDay2Shown() => _day2Shown = true;

  static void dismissDay2() {
    _day2Dismissed = true;
    _day2Shown = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _secondEntryShown = false;
    _secondEntryDismissed = false;
    _day2Shown = false;
    _day2Dismissed = false;
  }
}