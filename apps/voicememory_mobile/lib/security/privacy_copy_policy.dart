import '../core/config/v1_capability_registry.dart';

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
      'Your archive file on this device is encrypted.';

  static const String lockArchiveMe = 'Protect this archive';

  /// Calm first-run / legal disclaimer — no encryption or therapy claims.
  static const String personalNotMedicalDisclaimer =
      'Your recordings and saved moments are personal. Some data may be stored '
      'on this device. ArchiveMe is not therapy, medical advice, or emergency '
      'support.';

  /// Shorter variant for compact trust rows — still requires an explicit choice.
  static const String nothingSentUnlessFeatureChosen =
      'Nothing is sent unless you choose a feature that needs it.';

  // ——— Consumer privacy copy sources ———

  static const List<String> consumerPrivacySources = [
    'lib/security/security_settings_copy.dart',
    'lib/features/trust/privacy_screen_copy.dart',
    'lib/record/record_screen_framing_copy.dart',
    'lib/screens/privacy_screen.dart',
    'lib/features/trust/terms_screen_copy.dart',
  ];

  static final List<RegExp> _allowedEncryptedContexts = [
    RegExp(r'optional encrypted backup', caseSensitive: false),
    RegExp(r'encrypt(?:ed)?\s+(?:a\s+)?backup', caseSensitive: false),
    RegExp(r'encrypted before it is', caseSensitive: false),
    RegExp(r'encrypted sync', caseSensitive: false),
    RegExp(r'archive file on this device is encrypted', caseSensitive: false),
    RegExp(
      r'saved moments and retained recordings are encrypted on this device',
      caseSensitive: false,
    ),
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

  static const List<String> globalBannedPhrases = [
    'therapy',
    'diagnosis',
    'medical',
    'treatment',
    'mental health score',
    'wellbeing score',
    'clinical score',
    'life score',
    'archiveme knows',
    'fake stats',
    'testimonial',
    'everything stays on device',
    'fully encrypted archive',
    '100% secure',
    'unhackable',
    'voice memory',
    'voicememory',
    'ai',
    'artificial intelligence',
    'diagnose',
    'disorder',
    'therapist',
  ];

  static const List<String> _privacySuperlativePhrases = [
    '100% safe',
    'military grade',
    'military-grade',
    'unbreakable',
    'impossible to access',
    'nothing ever leaves your device',
    'delete from every server',
    'all journal data is encrypted',
    'your journal is encrypted',
    'entries are encrypted',
  ];

  /// Returns human-readable violation reasons for a user-visible string literal.
  static List<String> violationsInLiteral(String line) {
    if (line.isEmpty || line.contains(r'${')) return const [];

    final lower = line.toLowerCase();
    final violations = <String>[];

    if (_neverSentPattern.hasMatch(line) &&
        !lower.contains('unless you choose')) {
      violations.add(
        'overbroad "never sent/leaves" without "unless you choose"',
      );
    }

    for (final phrase in globalBannedPhrases) {
      if (_phraseMatches(lower, phrase) &&
          !_isAllowedBannedPhraseContext(lower, phrase)) {
        violations.add(phrase);
      }
    }

    for (final phrase in _privacySuperlativePhrases) {
      if (lower.contains(phrase)) {
        violations.add('banned phrase "$phrase"');
      }
    }

    if (_anonymousPattern.hasMatch(line)) {
      violations.add('anonymous claim (not a supported product promise)');
    }

    if (_encryptPattern.hasMatch(line) &&
        !_allowedEncryptedContexts.any((pattern) => pattern.hasMatch(line))) {
      violations.add('encryption claim without supported backup/sync context');
    }

    return violations;
  }

  static bool _phraseMatches(String lower, String phrase) {
    if (phrase == 'ai') {
      return RegExp(r'\bai\b', caseSensitive: false).hasMatch(lower);
    }
    return lower.contains(phrase);
  }

  /// A denial standing before the phrase, in the same literal.
  ///
  /// Long disclaimers are written as concatenated literals, so "ArchiveMe is
  /// not therapy, medical advice, or emergency support" reaches this check
  /// split after "medical". Matching only the exact pair "medical advice"
  /// therefore flags the very sentence that disclaims the thing.
  static bool _deniedBefore(String lower, String phrase) {
    final at = lower.indexOf(phrase);
    if (at <= 0) return false;
    return RegExp(
      r'\b(?:is|are|was|were|does|do|can|will)?\s*not\b|\bnever\b|\bno\b',
    ).hasMatch(lower.substring(0, at));
  }

  static bool _isAllowedBannedPhraseContext(String lower, String phrase) {
    switch (phrase) {
      case 'therapy':
        return lower.contains('not therapy') || _deniedBefore(lower, phrase);
      case 'medical':
        return lower.contains('not medical') ||
            lower.contains('medical advice') ||
            _deniedBefore(lower, phrase);
      case 'treatment':
        return lower.contains('not treatment') || _deniedBefore(lower, phrase);
      case 'diagnosis':
      case 'diagnose':
        return lower.contains('not diagnos') || _deniedBefore(lower, phrase);
      default:
        return false;
    }
  }

  static bool _allowlistedLine(String path, String line) {
    if (line.trim().startsWith('import ')) return true;
    if (line.trim().startsWith('//')) return true;
    if (line.contains('package:voicememory_mobile')) return true;
    if (line.contains('PrivacyCopyPolicy.')) return true;
    if (line.contains('bannedFirstImpressionPhrases') ||
        line.contains('bannedTerms') ||
        line.contains('bannedInternalTerms') ||
        line.contains('globalBannedPhrases')) {
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

enum PrivacyAnalysisMode { onDevice, remote, mixed }

/// Capability-backed privacy facts used by Record, Account, and privacy UI.
class PrivacyCapabilitySnapshot {
  const PrivacyCapabilitySnapshot({
    required this.journalTextEncryptedAtRest,
    required this.retainedAudioEncryptedAtRest,
    required this.keysUsePlatformSecureStorage,
    required this.biometricLockAvailable,
    required this.biometricLockEnabled,
    required this.syncEnabled,
    required this.syncEndToEndEncryptionVerified,
    required this.analysisMode,
    required this.permissions,
  });

  static const focusedV1 = PrivacyCapabilitySnapshot(
    journalTextEncryptedAtRest: true,
    retainedAudioEncryptedAtRest: true,
    keysUsePlatformSecureStorage: true,
    biometricLockAvailable: V1CapabilityRegistry.biometricLock,
    biometricLockEnabled: false,
    syncEnabled: false,
    syncEndToEndEncryptionVerified: false,
    analysisMode: PrivacyAnalysisMode.mixed,
    permissions: V1CapabilityRegistry.androidPermissionAllowlist,
  );

  final bool journalTextEncryptedAtRest;
  final bool retainedAudioEncryptedAtRest;
  final bool keysUsePlatformSecureStorage;
  final bool biometricLockAvailable;
  final bool biometricLockEnabled;
  final bool syncEnabled;
  final bool syncEndToEndEncryptionVerified;
  final PrivacyAnalysisMode analysisMode;
  final Set<String> permissions;

  PrivacyCapabilitySnapshot withRuntimeState({
    required bool biometricLockEnabled,
  }) => PrivacyCapabilitySnapshot(
    journalTextEncryptedAtRest: journalTextEncryptedAtRest,
    retainedAudioEncryptedAtRest: retainedAudioEncryptedAtRest,
    keysUsePlatformSecureStorage: keysUsePlatformSecureStorage,
    biometricLockAvailable: biometricLockAvailable,
    biometricLockEnabled: biometricLockEnabled,
    syncEnabled: syncEnabled,
    syncEndToEndEncryptionVerified: syncEndToEndEncryptionVerified,
    analysisMode: analysisMode,
    permissions: permissions,
  );

  String get recordReassurance {
    if (journalTextEncryptedAtRest && retainedAudioEncryptedAtRest) {
      return 'Saved moments and retained recordings are encrypted on this device.';
    }
    if (journalTextEncryptedAtRest) {
      return PrivacyCopyPolicy.journalEncryptedAtRest;
    }
    return PrivacyCopyPolicy.nothingSentUnlessFeatureChosen;
  }

  List<String> get accountSummary => [
    if (journalTextEncryptedAtRest)
      PrivacyCopyPolicy.journalEncryptedAtRest
    else
      'Journal storage encryption is not verified.',
    if (retainedAudioEncryptedAtRest)
      'Saved recordings are encrypted on this device.'
    else
      'Saved recording encryption is not verified.',
    if (keysUsePlatformSecureStorage)
      'Encryption keys use platform secure storage.',
    if (biometricLockAvailable)
      biometricLockEnabled
          ? 'Biometric archive lock is on.'
          : 'Biometric archive lock is off.',
    switch (analysisMode) {
      PrivacyAnalysisMode.onDevice => 'Analysis runs on this device.',
      PrivacyAnalysisMode.remote =>
        'Remote analysis is used when you choose a feature that needs it.',
      PrivacyAnalysisMode.mixed =>
        'Analysis may run on this device or remotely, depending on the feature.',
    },
    if (analysisMode != PrivacyAnalysisMode.onDevice)
      'Only data required for the selected remote analysis is sent.',
    if (!syncEnabled)
      'Cross-device sync is off.'
    else if (syncEndToEndEncryptionVerified)
      'Cross-device sync encryption is verified end to end.'
    else
      'Cross-device sync is enabled; end-to-end encryption is not verified.',
    'Microphone access is requested only when you start voice recording.',
    PrivacyCopyPolicy.exportDeleteAnytime,
  ];
}
