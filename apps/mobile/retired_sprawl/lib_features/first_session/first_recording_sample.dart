import 'package:flutter/foundation.dart';

/// First Recording Sample — one tiny starter sentence for zero-entry users,
/// reducing blank-page fear before the very first recording.
///
/// Not a prompt list, not homework: a single editable line the user can use,
/// change, or ignore. The CTA seeds the existing recording flow (the starter
/// shows as the "Try saying" helper); the normal recording path is untouched.
abstract class FirstRecordingSample {
  FirstRecordingSample._();

  static const String title = 'Use this as a starting point';
  static const String sample = 'Something I keep coming back to is\u2026';
  static const String helper =
      'Change it, ignore it, or record your own words.';
  static const String ctaLabel = 'Use this starter';

  /// Session-scoped attribution marker: set when the starter CTA seeds a
  /// recording, cleared once the first save is attributed. No content is
  /// ever carried — only the fact that the starter began the recording.
  static bool startedFromSampleThisSession = false;

  /// The sample exists only for a completely empty archive.
  static bool shouldShow(int entryCount) => entryCount == 0;

  @visibleForTesting
  static void resetForTest() => startedFromSampleThisSession = false;
}