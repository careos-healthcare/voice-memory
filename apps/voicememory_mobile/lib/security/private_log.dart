import 'package:flutter/foundation.dart';

import 'ai_prompt_boundary.dart';
import 'user_content_safety.dart';

/// Privacy-safe logging helpers — never emit full journal text or secrets.
abstract class PrivateLog {
  PrivateLog._();

  static void userTextField({
    required String tag,
    required String field,
    String? text,
    bool? promptInjection,
  }) {
    final value = text ?? '';
    final sanitized = UserContentSafety.sanitizePlainText(value);
    debugPrint(
      '$tag $field '
      'present=${sanitized.isNotEmpty} '
      'length=${sanitized.length} '
      'hash=${UserContentSafety.privacyHash(sanitized)}'
      '${promptInjection == null ? '' : ' promptInjection=$promptInjection'}',
    );
  }

  static void apiPayload({
    required String tag,
    required String operation,
    required String preparedText,
  }) {
    debugPrint('$tag $operation ${AiPromptBoundary.logSummary(preparedText)}');
  }
}
