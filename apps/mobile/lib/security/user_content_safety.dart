import 'dart:convert';

/// Sanitizes and inspects untrusted user journal text before display or API use.
abstract class UserContentSafety {
  UserContentSafety._();

  static const int maxPlainTextChars = 50000;
  static const int defaultSnippetChars = 240;

  static final RegExp _nullBytePattern = RegExp(r'\x00');
  static final RegExp _controlCharsExceptNewlineTab = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );
  static final RegExp _bidiOverridePattern = RegExp(
    r'[\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _zeroWidthPattern = RegExp(r'[\u200B-\u200D\uFEFF]');

  static final List<RegExp> _promptInjectionPatterns = [
    RegExp(r'ignore\s+(all\s+)?previous\s+instructions', caseSensitive: false),
    RegExp(r'\bsystem\s+prompt\b', caseSensitive: false),
    RegExp(r'\bdeveloper\s+message\b', caseSensitive: false),
    RegExp(r'reveal\s+(your\s+)?instructions', caseSensitive: false),
    RegExp(r'\bact\s+as\b', caseSensitive: false),
    RegExp(r'\bjailbreak\b', caseSensitive: false),
    RegExp(r'\bbypass\b', caseSensitive: false),
    RegExp(r'run\s+this\s+command', caseSensitive: false),
    RegExp(r'\bexfiltrate\b', caseSensitive: false),
    RegExp(r'\bapi\s+key\b', caseSensitive: false),
    RegExp(r'\bsecret\s+key\b', caseSensitive: false),
  ];

  static final List<RegExp> _secretPatterns = [
    RegExp('sk-[A-Za-z0-9]{20,}'),
    RegExp('rk_[A-Za-z0-9]{20,}'),
    RegExp(r'AIza[0-9A-Za-z\-_]{20,}'),
    RegExp(r'xox[baprs]-[0-9A-Za-z\-]{10,}'),
    RegExp(
      r'(api[_-]?key|secret[_-]?key|access[_-]?token|password)\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*'),
    RegExp('-----BEGIN (?:RSA |EC )?PRIVATE KEY-----'),
  ];

  /// Removes dangerous invisible characters, normalizes whitespace, caps length.
  /// Does not strip normal emotional language.
  static String sanitizePlainText(String input) {
    var text = input.replaceAll(_nullBytePattern, '');
    text = text.replaceAll(_controlCharsExceptNewlineTab, '');
    text = text.replaceAll(_bidiOverridePattern, '');
    text = text.replaceAll(_zeroWidthPattern, '');
    text = text.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();
    if (text.length > maxPlainTextChars) {
      text = text.substring(0, maxPlainTextChars).trimRight();
    }
    return text;
  }

  /// Plain-text preview with ellipsis cap — no HTML or markdown interpretation.
  static String safeSnippet(
    String input, {
    int maxChars = defaultSnippetChars,
  }) {
    final sanitized = sanitizePlainText(input);
    if (sanitized.isEmpty) return '';
    final limit = maxChars.clamp(1, maxPlainTextChars);
    if (sanitized.length <= limit) return sanitized;
    final slice = sanitized.substring(0, limit);
    final lastSpace = slice.lastIndexOf(' ');
    if (lastSpace > limit ~/ 2) {
      return '${slice.substring(0, lastSpace).trim()}…';
    }
    return '${slice.trim()}…';
  }

  /// Flags obvious prompt-injection phrases; does not block normal journaling.
  static bool looksLikePromptInjection(String input) {
    final normalized = sanitizePlainText(input).toLowerCase();
    if (normalized.isEmpty) return false;

    var hits = 0;
    for (final pattern in _promptInjectionPatterns) {
      if (pattern.hasMatch(normalized)) hits++;
    }

    if (hits >= 2) return true;

    const strongSingles = [
      'ignore previous instructions',
      'ignore all previous instructions',
      'reveal your instructions',
      'system prompt',
      'developer message',
      'jailbreak',
      'exfiltrate',
    ];
    for (final phrase in strongSingles) {
      if (normalized.contains(phrase)) return true;
    }

    return false;
  }

  /// Detects likely API keys, tokens, or password patterns.
  static bool containsPossibleSecret(String input) {
    final text = input.trim();
    if (text.isEmpty) return false;
    for (final pattern in _secretPatterns) {
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }

  /// Replaces likely secrets with a redaction marker.
  static String redactSecrets(String input) {
    var text = input;
    for (final pattern in _secretPatterns) {
      text = text.replaceAll(pattern, '[REDACTED_SECRET]');
    }
    return text;
  }

  /// Short hash for privacy-safe logging — never logs full private text.
  static String privacyHash(String input) {
    final bytes = utf8.encode(sanitizePlainText(input));
    if (bytes.isEmpty) return 'empty';
    var hash = 0;
    for (final b in bytes) {
      hash = 0x1fffffff & (hash + b);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash.toRadixString(16).padLeft(8, '0');
  }
}