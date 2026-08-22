/// Detects legacy phrase-built pattern copy that must never reach users.
abstract class LegacyPatternCopyGuard {
  LegacyPatternCopyGuard._();

  static const blockedSubstrings = [
    'follow a heavy should',
    'follow a heavy',
    'is test to see',
    'test to see if',
    'test to see',
    'what you feel you should do',
    'you may do more when',
    'seems to return around',
    'the repeated thread may be',
  ];

  static final blockedPatterns = [
    RegExp(r'\baround\s+pressure\b', caseSensitive: false),
    RegExp(r'\bwhen\s+pressure from\b', caseSensitive: false),
    RegExp(r'\bnotice whether .+ shows up again', caseSensitive: false),
  ];

  static const naturalTrailingPhrases = [
    'does not want to',
    'do not want to',
    'did not want to',
    "didn't want to",
    'you do not want to',
  ];

  static bool containsLegacyCopy(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return false;
    for (final blocked in blockedSubstrings) {
      if (lower.contains(blocked)) return true;
    }
    for (final pattern in blockedPatterns) {
      if (pattern.hasMatch(lower)) return true;
    }
    return false;
  }

  static bool hasNaturalTrailingPhrase(String text) {
    final lower = text.trim().toLowerCase().replaceAll(RegExp(r'[.?!]+$'), '');
    return naturalTrailingPhrases.any(lower.endsWith);
  }
}