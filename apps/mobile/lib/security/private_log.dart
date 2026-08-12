import 'package:archiveme_mobile/security/ai_prompt_boundary.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';

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
    ReleaseLogger.emit(
      event: 'private_user_text_field',
      category: ReleaseLogCategory.storage,
      fields: {
        'tag': tag,
        'field': field,
        'present': sanitized.isNotEmpty,
        'length_bucket': ReleaseLogSanitizer.lengthBucket(sanitized.length),
        if (promptInjection != null) 'prompt_injection': promptInjection,
      },
    );
  }

  static void apiPayload({
    required String tag,
    required String operation,
    required String preparedText,
  }) {
    ReleaseLogger.emit(
      event: 'private_api_payload',
      category: ReleaseLogCategory.network,
      fields: {
        'tag': ReleaseLogSanitizer.sanitizeReasonCode(tag),
        'operation': ReleaseLogSanitizer.sanitizeReasonCode(operation),
        ...AiPromptBoundary.logFields(preparedText),
      },
    );
  }
}
