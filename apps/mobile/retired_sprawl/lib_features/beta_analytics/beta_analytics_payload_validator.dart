import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_event_registry.dart';
import 'package:flutter/foundation.dart';

/// Why a beta analytics payload attribute was refused.
enum BetaAnalyticsValidationReason {
  unknownEvent,
  forbiddenKey,
  unknownKey,
  invalidEnum,
  invalidValueShape,
  sentinelContent,
}

@immutable
class BetaAnalyticsValidationDrop {
  const BetaAnalyticsValidationDrop({
    required this.event,
    required this.key,
    required this.reason,
  });

  final String event;
  final String key;
  final BetaAnalyticsValidationReason reason;
}

/// Schema validation for the beta analytics registry.
///
/// Runs before [ProofAnalyticsGuard] and rejects sentinel content patterns.
class BetaAnalyticsPayloadValidator {
  BetaAnalyticsPayloadValidator._();

  static final List<BetaAnalyticsValidationDrop> _drops =
      <BetaAnalyticsValidationDrop>[];

  @visibleForTesting
  static List<BetaAnalyticsValidationDrop> get drops =>
      List.unmodifiable(_drops);

  @visibleForTesting
  static void resetForTest() => _drops.clear();

  /// Sentinel strings that must never appear in any payload value.
  static const List<String> sentinelPatterns = [
    'SENTINEL_TRANSCRIPT_LEAK',
    'SENTINEL_CORRECTION_LEAK',
    'SENTINEL_EVIDENCE_LEAK',
    'I said yes again at work',
    'why do I keep saying yes',
  ];

  static const Set<String> forbiddenExactKeys = {
    'transcript',
    'audio',
    'correction_text',
    'generated_text',
    'evidence_text',
    'token',
    'path',
    'filepath',
    'hash',
    'fingerprint',
    'errormessage',
    'stacktrace',
    'entry_id',
    'proof_id',
    'archive_id',
  };

  static const Set<String> forbiddenKeySubstrings = {
    'transcript',
    'audio',
    'correction',
    'generated',
    'evidence_text',
    'token',
    'filepath',
    'fingerprint',
    'hash',
    'errormessage',
    'stacktrace',
    'entryid',
    'proofid',
  };

  static final RegExp _idShape = RegExp(r'^[a-z0-9_]{1,40}$');

  /// Returns validated payload or null when the event is unknown.
  static Map<String, Object>? validate(
    String eventName,
    Map<String, Object>? parameters,
  ) {
    final def = BetaAnalyticsEventRegistry.definitionFor(eventName);
    if (def == null) {
      _record(eventName, '*', BetaAnalyticsValidationReason.unknownEvent);
      return null;
    }

    if (parameters == null || parameters.isEmpty) {
      if (def.allowedPayloadKeys.isEmpty) return const {};
      return const {};
    }

    final safe = <String, Object>{};
    for (final entry in parameters.entries) {
      final key = _normalizeKey(entry.key);
      if (key.isEmpty) continue;

      if (forbiddenExactKeys.contains(key) ||
          _hasForbiddenSubstring(key)) {
        _record(eventName, key, BetaAnalyticsValidationReason.forbiddenKey);
        continue;
      }

      if (!def.allowedPayloadKeys.contains(key)) {
        _record(eventName, key, BetaAnalyticsValidationReason.unknownKey);
        continue;
      }

      final value = entry.value;
      if (value is! String && value is! num && value is! bool) {
        _record(
          eventName,
          key,
          BetaAnalyticsValidationReason.invalidValueShape,
        );
        continue;
      }

      final stringValue = value.toString();
      if (_containsSentinel(stringValue)) {
        _record(eventName, key, BetaAnalyticsValidationReason.sentinelContent);
        continue;
      }

      if (value is String && !_idShape.hasMatch(value)) {
        _record(
          eventName,
          key,
          BetaAnalyticsValidationReason.invalidValueShape,
        );
        continue;
      }

      final allowedEnums = def.enumConstraints[key];
      if (allowedEnums != null && allowedEnums.isNotEmpty) {
        if (!allowedEnums.contains(stringValue)) {
          _record(eventName, key, BetaAnalyticsValidationReason.invalidEnum);
          continue;
        }
      }

      safe[key] = value is String ? value : value;
    }

    return safe;
  }

  static bool _containsSentinel(String value) {
    final lower = value.toLowerCase();
    for (final pattern in sentinelPatterns) {
      if (lower.contains(pattern.toLowerCase())) return true;
    }
    return false;
  }

  static bool _hasForbiddenSubstring(String key) {
    for (final pattern in forbiddenKeySubstrings) {
      if (key.contains(pattern)) return true;
    }
    return false;
  }

  static String _normalizeKey(String key) => key
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9_]'), '_')
      .replaceAll(RegExp('_+'), '_');

  static void _record(
    String event,
    String key,
    BetaAnalyticsValidationReason reason,
  ) {
    if (_drops.length < 200) {
      _drops.add(
        BetaAnalyticsValidationDrop(event: event, key: key, reason: reason),
      );
    }
    if (kDebugMode) {
      AppLogger.debug('BetaAnalyticsPayloadValidator: dropped $event.$key ($reason)');
    }
  }
}
