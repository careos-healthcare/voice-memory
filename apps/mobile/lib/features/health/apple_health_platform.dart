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

  static bool get isIos {
    if (kIsWeb) return false;
    return debugIsIos ?? Platform.isIOS;
  }
}
