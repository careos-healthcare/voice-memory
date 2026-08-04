import 'package:flutter/foundation.dart';

/// First Save Rescue — session-scoped attribution marker.
///
/// When a brand-new user starts recording from the rescue card, this flag
/// lets the journal store attribute the very first save to the rescue path
/// without threading context through the recording flow. No content is ever
/// carried — only the fact that the rescue CTA started the recording.
abstract class FirstSaveRescue {
  FirstSaveRescue._();

  /// Set when the rescue CTA starts a recording; cleared after the first
  /// save is attributed (or when the session ends).
  static bool startedFromRescueThisSession = false;

  /// The rescue exists only for users with an empty archive.
  static bool shouldShow(int entryCount) => entryCount == 0;

  @visibleForTesting
  static void resetForTest() => startedFromRescueThisSession = false;
}
