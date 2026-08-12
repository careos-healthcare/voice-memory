import 'package:archiveme_mobile/core/network/api_failure.dart';

/// Sanitizes release log fields — no paths, ids, content, tokens, or hashes.
abstract final class ReleaseLogSanitizer {
  ReleaseLogSanitizer._();

  static const forbiddenFieldKeys = {
    'path',
    'audio_path',
    'audiopath',
    'file_path',
    'filepath',
    'local_path',
    'entry_id',
    'entryid',
    'archive_id',
    'proof_id',
    'evidence_id',
    'transcript',
    'body',
    'observation',
    'note',
    'notes',
    'insight',
    'correction',
    'email',
    'token',
    'secret',
    'hash',
    'fingerprint',
    'url',
    'stack',
    'stacktrace',
    'exception',
    'errormessage',
    'message',
    'payload',
    'request_body',
    'response_body',
    'detail',
    'reason',
    'filename',
    'firstbytes',
  };

  static final RegExp _safeToken = RegExp(r'^[a-z][a-z0-9_]{0,47}$');
  static final RegExp _pathLike = RegExp(r'[/\\]|\.m4a|\.wav|\.caf|\.mp3|/tmp/');
  static final RegExp _emailLike = RegExp(r'@[a-z0-9.-]+\.[a-z]{2,}', caseSensitive: false);
  static final RegExp _tokenLike = RegExp(
    r'Bearer\s+|sk-[A-Za-z0-9]{8,}|rk_[A-Za-z0-9]{8,}|whsec_[A-Za-z0-9]{8,}',
  );

  static Map<String, Object> sanitizeFields(
    Map<String, Object?> fields, {
    required bool releaseMode,
  }) {
    if (!releaseMode) {
      final out = <String, Object>{};
      for (final entry in fields.entries) {
        final value = entry.value;
        if (value != null) out[entry.key] = value as Object;
      }
      return out;
    }

    final safe = <String, Object>{};
    for (final entry in fields.entries) {
      final key = _normalizeKey(entry.key);
      if (key.isEmpty || forbiddenFieldKeys.contains(key)) continue;
      final value = entry.value;
      if (value == null) continue;
      if (value is bool || value is int) {
        safe[key] = value;
        continue;
      }
      if (value is double) {
        if (!value.isNaN && !value.isInfinite) safe[key] = value;
        continue;
      }
      if (value is String) {
        final sanitized = sanitizeReasonCode(value);
        if (sanitized != null) safe[key] = sanitized;
      }
    }
    return safe;
  }

  static String? sanitizeReasonCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (_pathLike.hasMatch(trimmed) ||
        _emailLike.hasMatch(trimmed) ||
        _tokenLike.hasMatch(trimmed)) {
      return 'operation_failed';
    }
    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) return 'operation_failed';
    if (_safeToken.hasMatch(normalized)) return normalized;
    if (normalized.startsWith('native_stt')) return 'native_stt_failed';
    if (normalized.contains('offline')) return 'offline';
    if (normalized.contains('timeout')) return 'timeout';
    if (normalized.contains('permission')) return 'permission_denied';
    if (normalized.contains('cancel')) return 'cancelled';
    return 'operation_failed';
  }

  static String errorCodeFromApiFailure(ApiFailure failure) {
    final code = sanitizeReasonCode(failure.code);
    return code ?? 'api_failure';
  }

  static String errorCodeFromObject(Object? error) {
    if (error is ApiFailure) return errorCodeFromApiFailure(error);
    if (error is FormatException) return 'parse_error';
    if (error is StateError) return 'invalid_state';
    return sanitizeReasonCode(error.runtimeType.toString()) ?? 'operation_failed';
  }

  static String bytesBucket(int bytes) {
    if (bytes <= 0) return 'empty';
    if (bytes < 1024) return 'lt_1kb';
    if (bytes < 16 * 1024) return 'lt_16kb';
    if (bytes < 256 * 1024) return 'lt_256kb';
    if (bytes < 1024 * 1024) return 'lt_1mb';
    return 'gte_1mb';
  }

  static String lengthBucket(int length) {
    if (length <= 0) return 'zero';
    if (length < 32) return 'lt_32';
    if (length < 256) return 'lt_256';
    if (length < 2048) return 'lt_2048';
    return 'gte_2048';
  }

  static String durationBucket(int? ms) {
    if (ms == null || ms < 0) return 'unknown';
    if (ms < 100) return 'lt_100ms';
    if (ms < 1000) return 'lt_1s';
    if (ms < 5000) return 'lt_5s';
    if (ms < 30000) return 'lt_30s';
    return 'gte_30s';
  }

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');
}
