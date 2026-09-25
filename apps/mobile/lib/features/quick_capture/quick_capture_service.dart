import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Release diagnostic for the quick-capture surfaces that ship with the
/// widget extension.
abstract final class QuickCaptureService {
  QuickCaptureService._();

  /// Logs one line per surface in release builds when
  /// [V1CapabilityRegistry.nativeQuickCapture] is on.
  static void auditQuickCaptureCapabilities() {
    if (!kReleaseMode || !V1CapabilityRegistry.nativeQuickCapture) return;
    final matrix = supportMatrix();
    for (final entry in matrix.entries) {
      AppLogger.debug(
        'quick_capture surface=${entry.key} supported=${entry.value}',
      );
    }
  }

  /// Runtime support for each quick-capture surface on this device.
  static Map<String, bool> supportMatrix({
    bool? isIos,
    int? major,
    bool? watch,
  }) {
    final ios = isIos ?? (!kIsWeb && Platform.isIOS);
    final version = major ?? _iosMajor();
    final watchOn = watch ?? V1CapabilityRegistry.watchCompanion;
    final widgets = ios && version >= 16;
    return {
      'siri': ios,
      'shortcuts': ios,
      'actionButton': ios && version >= 18,
      'controlCenter': ios && version >= 18,
      'homeWidget': widgets,
      'lockWidget': widgets,
      'liveActivity': ios && version >= 16,
      'watchCompanion': ios && watchOn,
    };
  }

  static int _iosMajor() {
    if (kIsWeb || !Platform.isIOS) return 0;
    final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
