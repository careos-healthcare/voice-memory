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

  /// This file declares the banned vocabulary, so scanning it would only ever
  /// report its own rule table.
  static const String policySelfPath = 'lib/security/privacy_copy_policy.dart';

  /// Path fragments that mark a Dart file as a user-facing privacy, trust, or
  /// consent surface even when it is not a `*_copy.dart` constants class.
  static final RegExp _surfacePathPattern = RegExp(
    'privacy|trust|consent|security|onboarding',
    caseSensitive: false,
  );

  /// Whether [path] holds copy a user can read on a privacy or trust surface.
  ///
  /// This predicate — not a hand-maintained list — decides what gets scanned.
  /// A caller walks `lib/` and asks about every Dart file it finds, so a new
  /// copy file is covered the moment it lands. Widen the predicate rather than
  /// enumerating files; [consumerPrivacySources] exists only for the handful
  /// of surfaces whose path says nothing about what they contain.
  static bool isConsumerPrivacySource(String path) {
    final normalized = path.replaceAll(r'\', '/');
    if (!normalized.endsWith('.dart')) return false;
    if (!normalized.startsWith('lib/')) return false;
    if (normalized == policySelfPath) return false;
    if (normalized.endsWith('_copy.dart')) return true;
    if (consumerPrivacySources.contains(normalized)) return true;
    return _surfacePathPattern.hasMatch(normalized);
  }

  /// Surfaces that discovery cannot infer from the path, listed explicitly.
  ///
  /// Not the scan set — discovery is. A guard test asserts every entry here
  /// still exists, so this list fails loudly instead of rotting the way the
  /// previous hand-maintained scan set did.
  static const List<String> consumerPrivacySources = [
    'lib/security/archive_privacy_controls_copy.dart',
    'lib/security/account_privacy_controls_copy.dart',
    'lib/security/security_settings_copy.dart',
    'lib/features/trust/pro_trust_copy.dart',
    'lib/record/record_screen_framing_copy.dart',
    'lib/auth/auth_trigger_rules.dart',
    'lib/screens/privacy_screen.dart',
    'lib/widgets/security/archive_data_flow_sheet.dart',
    'lib/widgets/security/archive_privacy_controls_card.dart',
    'lib/widgets/account/account_privacy_controls_section.dart',
    'lib/features/privacy/privacy_security_trust_copy.dart',
    'lib/widgets/settings/privacy_security_trust_section.dart',
    'lib/features/trust/terms_screen_copy.dart',
    'lib/features/onboarding/first_user_experience_copy.dart',
    'lib/features/onboarding/ui/remote_processing_consent_copy.dart',
    'lib/features/settings/ui/on_device_architecture_copy.dart',
    'lib/features/settings/ui/on_device_architecture_section.dart',
  ];

  static final List<RegExp> _allowedEncryptedContexts = [
    RegExp('optional encrypted backup', caseSensitive: false),
    RegExp(r'encrypt(?:ed)?\s+(?:a\s+)?backup', caseSensitive: false),
    RegExp('encrypted before it is', caseSensitive: false),
    RegExp('encrypted sync', caseSensitive: false),
    RegExp('journal file on this device is encrypted', caseSensitive: false),
  ];

  static final RegExp _neverSentPattern = RegExp(
    'never sent|never leaves|nothing ever leaves',
    caseSensitive: false,
  );

  static final RegExp _encryptPattern = RegExp(
    'encrypt',
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
      final unexcused = _bannedPhraseOccurrences(lower, phrase).any(
        (index) => !_isAllowedBannedPhraseContext(lower, phrase, index),
      );
      if (unexcused) violations.add(phrase);
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

  static final RegExp _aiWordPattern = RegExp(r'\bai\b', caseSensitive: false);

  /// Start offsets of every occurrence of [phrase] in [lower].
  ///
  /// Positions, not a bool, because whether a banned word is a claim depends
  /// on the words immediately before *that* occurrence. A literal offends if
  /// any one occurrence is unexcused.
  static List<int> _bannedPhraseOccurrences(String lower, String phrase) {
    if (phrase == 'ai') {
      return _aiWordPattern.allMatches(lower).map((m) => m.start).toList();
    }
    final occurrences = <int>[];
    var index = lower.indexOf(phrase);
    while (index >= 0) {
      occurrences.add(index);
      index = lower.indexOf(phrase, index + 1);
    }
    return occurrences;
  }

  static bool _isAllowedBannedPhraseContext(
    String lower,
    String phrase,
    int index,
  ) {
    if (_isNegatedOccurrence(lower, index)) return true;
    switch (phrase) {
      case 'therapy':
        return lower.contains('not therapy');
      case 'medical':
        return lower.contains('not medical') ||
            lower.contains('medical advice');
      case 'treatment':
        return lower.contains('not treatment');
      case 'diagnosis':
      case 'diagnose':
        return lower.contains('not diagnos');
      default:
        return false;
    }
  }

  /// How far before a banned phrase a negating cue still governs it.
  ///
  /// Wide enough for "does not make medical, therapy, or diagnostic claims",
  /// short enough that an unrelated earlier "not" cannot excuse a real claim.
  static const int _negationWindow = 48;

  /// Where a negating cue stops carrying. Commas are deliberately absent:
  /// "no medical claims, no therapist-ready claims" is one prohibition list.
  static final RegExp _clauseBoundary = RegExp('[.;:!?—]');

  /// Cues that make what follows a rejection or a comparison rather than a
  /// promise — "No medical claims", "not a diagnosis", "Compare against Chat
  /// AI". A guard that forbids a word must not be read as claiming it.
  static final RegExp _negationCue = RegExp(
    r'\b(?:no|not|never|nor|without|nothing)\b'
    r'|\b(?:is|are|was|were|do|does|did|can|could|will|would|has|have)'
    r"n['’]t\b"
    r'|\b(?:compare|compares|compared|comparison)\s+(?:against|to|with)\b'
    r'|\b(?:instead\s+of|rather\s+than|unlike|versus|vs\.?)\b',
    caseSensitive: false,
  );

  /// Whether the banned phrase at [index] sits inside a negating or
  /// contrastive clause.
  ///
  /// Only text back to the nearest clause boundary counts, so "This is not
  /// advice. Diagnosis follows." keeps reporting the second sentence.
  static bool _isNegatedOccurrence(String lower, int index) {
    final start = index < _negationWindow ? 0 : index - _negationWindow;
    var prefix = lower.substring(start, index);
    final boundary = prefix.lastIndexOf(_clauseBoundary);
    if (boundary >= 0) prefix = prefix.substring(boundary + 1);
    return _negationCue.hasMatch(prefix);
  }

  /// Declarations whose contents are prohibitions, not promises — a guard
  /// listing `'therapy'` as forbidden must not be read as claiming therapy.
  static final RegExp _bannedVocabularyDeclaration = RegExp(
    r'\b(banned|forbidden)\w*\b',
    caseSensitive: false,
  );

  static bool _allowlistedLine(String path, String line) {
    if (line.trim().startsWith('import ')) return true;
    if (line.trim().startsWith('//')) return true;
    if (line.contains('package:voicememory_mobile')) return true;
    if (line.contains('PrivacyCopyPolicy.')) return true;
    return _bannedVocabularyDeclaration.hasMatch(line);
  }

  /// Whether [line] opens a multi-line banned-vocabulary collection.
  ///
  /// Without this the declaration line is skipped but its entries are not, so
  /// every guard list in the codebase reports itself once the scan is widened
  /// past hand-picked files.
  static bool _opensBannedVocabularyBlock(String line) {
    if (!_bannedVocabularyDeclaration.hasMatch(line)) return false;
    final opens = line.contains('[') || line.contains('{');
    final closes = line.contains(']') || line.contains('}');
    return opens && !closes;
  }

  static final RegExp _identifierCharacters = RegExp(r'^[A-Za-z0-9_./:%+-]+$');
  static final RegExp _camelCaseBoundary = RegExp('[a-z][A-Z]');

  /// Whether [value] is a machine token — a widget key, preference key, event
  /// name, or path fragment — rather than words a user reads.
  ///
  /// Widening the scan to whole screens pulls in literals like
  /// `encryption_status_card`, which carry no promise. A single plain word can
  /// still be a real label ("Diagnosis"), so only snake_case, dotted, pathed,
  /// or camelCase tokens are treated as machine identifiers.
  static bool isMachineIdentifierLiteral(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed.contains(' ')) return false;
    if (!_identifierCharacters.hasMatch(trimmed)) return false;
    return trimmed.contains('_') ||
        trimmed.contains('.') ||
        trimmed.contains('/') ||
        _camelCaseBoundary.hasMatch(trimmed);
  }

  /// Scans [path] for unsafe privacy promises in string literals.
  static List<String> scanFile(String path, String source) {
    final violations = <String>[];
    final literalPattern = RegExp("'([^']*)'");
    var insideBannedVocabulary = false;

    for (final line in source.split('\n')) {
      if (insideBannedVocabulary) {
        if (line.contains(']') || line.contains('}')) {
          insideBannedVocabulary = false;
        }
        continue;
      }
      if (_allowlistedLine(path, line)) {
        insideBannedVocabulary = _opensBannedVocabularyBlock(line);
        continue;
      }

      for (final match in literalPattern.allMatches(line)) {
        final value = match.group(1) ?? '';
        if (isMachineIdentifierLiteral(value)) continue;
        for (final reason in violationsInLiteral(value)) {
          violations.add('$path: $reason in "$value"');
        }
      }
    }

    return violations;
  }

  /// Scans every entry of [sourcesByPath], skipping paths that are not consumer
  /// privacy surfaces. Returns violations sorted so output is diffable.
  static List<String> scanSources(Map<String, String> sourcesByPath) {
    final violations = <String>[];
    final paths = sourcesByPath.keys.toList()..sort();
    for (final path in paths) {
      if (!isConsumerPrivacySource(path)) continue;
      violations.addAll(scanFile(path, sourcesByPath[path]!));
    }
    return violations;
  }
}
