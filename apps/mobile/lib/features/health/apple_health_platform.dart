import 'dart:io';

import 'package:flutter/foundation.dart';

/// Apple Health State of Mind is an iOS HealthKit type.
///
/// Android Health Connect has no matching mood type, so the badge and the
/// Settings controls stay off that platform.
abstract final class AppleHealthPlatform {
  AppleHealthPlatform._();

  @visibleForTesting
  static bool? debugIsIos;

  /// State of Mind exists on iOS 18 and later. Tests set this directly.
  @visibleForTesting
  static bool? debugSupportsStateOfMind;

  static bool get isIos {
    if (kIsWeb) return false;
    return debugIsIos ?? Platform.isIOS;
  }

  /// Android and iOS 17 and older do not show the Health row.
  static bool get supportsStateOfMind {
    final override = debugSupportsStateOfMind;
    if (override != null) return override;
    if (!isIos) return false;
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    final major = int.tryParse(match?.group(1) ?? '') ?? 0;
    return major >= 18;
  }
}
