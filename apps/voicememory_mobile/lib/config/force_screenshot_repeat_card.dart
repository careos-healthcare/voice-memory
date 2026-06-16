import 'package:flutter/foundation.dart';

import '../features/retention/second_session_signal_model.dart';
import '../product/consumer_ui_copy.dart';

/// Debug-only App Store capture override for the Patterns-tab repeat card.
///
/// ```bash
/// flutter run --dart-define=FORCE_SCREENSHOT_REPEAT_CARD=true
/// ```
abstract class ForceScreenshotRepeatCard {
  ForceScreenshotRepeatCard._();

  static const bool _fromEnvironment = bool.fromEnvironment(
    'FORCE_SCREENSHOT_REPEAT_CARD',
    defaultValue: false,
  );

  static bool? _testOverride;

  /// Test hook — never use in production code paths.
  @visibleForTesting
  static set testOverride(bool? value) => _testOverride = value;

  /// Active only in non-release builds when the dart-define is set.
  static bool get enabled {
    if (kReleaseMode) return false;
    if (_testOverride != null) return _testOverride!;
    return _fromEnvironment;
  }

  /// Screenshot-ready possible-repeat card — matches [ConsumerUiCopy] fallback.
  static SecondSessionComparison get comparison =>
      const SecondSessionComparison(
        hasEnoughData: true,
        title: ConsumerUiCopy.secondSessionPossibleRepeatTitle,
        body: ConsumerUiCopy.secondSessionSoundsClose,
        whatRepeated: ConsumerUiCopy.secondSessionFallbackWhatRepeated,
        whatChanged: ConsumerUiCopy.secondSessionFallbackWhatChanged,
        whatToTestNext: ConsumerUiCopy.secondSessionFallbackWhatToTestNext,
        possibleRepeat: true,
      );
}
