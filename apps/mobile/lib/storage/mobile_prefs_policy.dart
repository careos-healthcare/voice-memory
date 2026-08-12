/// Guardrails for what may be stored in [MobilePrefsStore].
abstract final class MobilePrefsPolicy {
  MobilePrefsPolicy._();

  /// JSON field names that must never hold personal free text in prefs.
  static const personalContentFieldNames = {
    'correctionNotes',
    'renamed',
    'transcript',
    'body',
    'notes',
    'caption',
    'widgetTitle',
    'widgetBody',
    'checkQuestion',
    'insightBody',
    'freeText',
    'userText',
    'typedText',
    'reflectionText',
    'correctionNote',
  };

  /// Prefs keys whose entire JSON payload is personal content (encrypted elsewhere).
  static const encryptedPersonalContentKeys = {
    'secure_archive_insight_correction_notes_v1',
    'secure_pattern_custom_names_v1',
  };

  static List<String> violationsInSource(String path, String source) {
    final violations = <String>[];
    final writePattern = RegExp(
      r"write(?:JsonMap|String|Map)\(\s*'([^']+)'",
    );

    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
      if (path.contains('mobile_prefs_policy.dart')) continue;
      if (path.contains('sensitive_prefs_encrypted_blob.dart')) continue;
      if (_isMigrationOrAllowlistedLine(line)) continue;

      for (final field in personalContentFieldNames) {
        if (_lineReferencesFieldLiteral(line, field)) {
          violations.add('$path: personal content field "$field"');
        }
      }

      final writeMatch = writePattern.firstMatch(line);
      if (writeMatch != null) {
        final key = writeMatch.group(1)!;
        if (encryptedPersonalContentKeys.contains(key)) {
          continue;
        }
      }
    }

    return violations;
  }

  static bool _isMigrationOrAllowlistedLine(String line) {
    return line.contains('legacyFieldName') ||
        line.contains('_legacyCorrectionNotesField') ||
        line.contains('_legacyRenamedField') ||
        line.contains('payloadRootKey') ||
        line.contains('personalContentFieldNames') ||
        line.contains('securePrefsKey') ||
        line.contains('_secureCorrectionNotesKey') ||
        line.contains('_secureCustomNamesKey');
  }

  static bool _lineReferencesFieldLiteral(String line, String field) {
    return RegExp("'$field'").hasMatch(line) ||
        RegExp('"$field"').hasMatch(line);
  }
}
