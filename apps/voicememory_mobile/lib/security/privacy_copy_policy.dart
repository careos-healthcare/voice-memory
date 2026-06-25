/// Canonical privacy promises and guards against overclaiming in consumer copy.
abstract class PrivacyCopyPolicy {
  PrivacyCopyPolicy._();

  // ——— Allowed promise constants ———

  static const String privateByDefault = 'Private by default';

  static const String nothingSentUnlessChosen =
      'Nothing is sent unless you choose cloud, sync, or transcription.';

  static const String exportDeleteAnytime =
      'You can export or delete your local archive at any time.';

  static const String deleteLocalArchive = 'Delete local archive';

  static const String transcriptionAnalysisWhenUsed =
      'Some features send audio or text for transcription or analysis when you use them.';

  static const String journalEncryptedAtRest =
      'Your journal file on this device is encrypted.';

  static const String lockArchiveMe = 'Protect this archive';

  /// Calm first-run / legal disclaimer — no encryption or therapy claims.
  static const String personalNotMedicalDisclaimer =
      'Your recordings and reflections are personal. Some data may be stored '
      'on this device. ArchiveMe is not therapy, medical advice, or emergency '
      'support.';

  /// Shorter variant for compact trust rows — still requires an explicit choice.
  static const String nothingSentUnlessFeatureChosen =
      'Nothing is sent unless you choose a feature that needs it.';

  // ——— Consumer privacy copy sources ———

  static const List<String> consumerPrivacySources = [
    'lib/security/archive_privacy_controls_copy.dart',
    'lib/security/account_privacy_controls_copy.dart',
    'lib/security/security_settings_copy.dart',
    'lib/features/trust/privacy_screen_copy.dart',
    'lib/features/trust/pro_trust_copy.dart',
    'lib/record/record_screen_framing_copy.dart',
    'lib/auth/auth_trigger_rules.dart',
    'lib/screens/privacy_screen.dart',
    'lib/widgets/security/archive_data_flow_sheet.dart',
    'lib/widgets/security/archive_privacy_controls_card.dart',
    'lib/widgets/account/account_privacy_controls_section.dart',
    'lib/widgets/record/record_first_run_privacy_reassurance.dart',
    'lib/features/trust/terms_screen_copy.dart',
    'lib/features/onboarding/first_user_experience_copy.dart',
  ];

  static final List<RegExp> _allowedEncryptedContexts = [
    RegExp(r'optional encrypted backup', caseSensitive: false),
    RegExp(r'encrypt(?:ed)?\s+(?:a\s+)?backup', caseSensitive: false),
    RegExp(r'encrypted before it is', caseSensitive: false),
    RegExp(r'encrypted sync', caseSensitive: false),
    RegExp(r'journal file on this device is encrypted', caseSensitive: false),
  ];

  static final RegExp _neverSentPattern = RegExp(
    r'never sent|never leaves|nothing ever leaves',
    caseSensitive: false,
  );

  static final RegExp _encryptPattern = RegExp(
    r'encrypt',
    caseSensitive: false,
  );

  static final RegExp _anonymousPattern = RegExp(
    r'\banonymous\b',
    caseSensitive: false,
  );

  static const List<String> _bannedPhrases = [
    '100% secure',
    '100% safe',
    'military grade',
    'military-grade',
    'unhackable',
    'unbreakable',
    'impossible to access',
    'nothing ever leaves your device',
    'delete from every server',
    'all journal data is encrypted',
    'your journal is encrypted',
    'entries are encrypted',
  ];

  /// Returns human-readable violation reasons for a user-visible string literal.
  static List<String> violationsInLiteral(String value) {
    if (value.isEmpty || value.contains(r'${')) return const [];

    final lower = value.toLowerCase();
    final violations = <String>[];

    if (_neverSentPattern.hasMatch(value) &&
        !lower.contains('unless you choose')) {
      violations.add(
        'overbroad "never sent/leaves" without "unless you choose"',
      );
    }

    for (final phrase in _bannedPhrases) {
      if (lower.contains(phrase)) {
        violations.add('banned phrase "$phrase"');
      }
    }

    if (_anonymousPattern.hasMatch(value)) {
      violations.add('anonymous claim (not a supported product promise)');
    }

    if (_encryptPattern.hasMatch(value) &&
        !_allowedEncryptedContexts.any((pattern) => pattern.hasMatch(value))) {
      violations.add(
        'encryption claim without supported backup/sync context',
      );
    }

    return violations;
  }

  static bool _allowlistedLine(String path, String line) {
    if (line.trim().startsWith('import ')) return true;
    if (line.trim().startsWith('//')) return true;
    if (line.contains('package:voicememory_mobile')) return true;
    if (line.contains('PrivacyCopyPolicy.')) return true;
    if (line.contains('bannedFirstImpressionPhrases') ||
        line.contains('bannedTerms') ||
        line.contains('bannedInternalTerms')) {
      return true;
    }
    return false;
  }

  /// Scans [path] for unsafe privacy promises in string literals.
  static List<String> scanFile(String path, String source) {
    final violations = <String>[];
    final literalPattern = RegExp(r"'([^']*)'");

    for (final line in source.split('\n')) {
      if (_allowlistedLine(path, line)) continue;

      for (final match in literalPattern.allMatches(line)) {
        final value = match.group(1) ?? '';
        for (final reason in violationsInLiteral(value)) {
          violations.add('$path: $reason in "$value"');
        }
      }
    }

    return violations;
  }
}
