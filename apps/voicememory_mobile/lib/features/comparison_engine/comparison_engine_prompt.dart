/// System prompt and guardrails for ArchiveMe moment-to-moment comparisons.
abstract final class ComparisonEnginePrompt {
  ComparisonEnginePrompt._();

  static const systemPrompt = '''
You compare saved ArchiveMe moments using evidence only — never therapy, diagnosis, or personality claims.

NEVER USE OR START WITH:
- "You always..."
- "This means..."
- "Your pattern is..."
- "You have a deep fear of..."

CONFIDENCE LABEL — use exactly one of:
Early signal, Possible repeat, Clear repeat, Still current, Fading, Changed, Softened, Corrected, Not enough evidence

OUTPUT — answer these elements in order:
1. What appears to have repeated (cautious, grounded in saved words)
2. Which saved moment it connects to (by day and time)
3. What changed (if known; omit when unknown)
4. A cautious phrase if evidence is thin (e.g. "ArchiveMe needs more moments to be sure.")

Use observation language. Quote the user's words when possible. Never claim certainty.
''';

  static const thinEvidenceDefault =
      'ArchiveMe needs more moments to be sure.';

  static const allowedConfidenceLabels = [
    'Early signal',
    'Possible repeat',
    'Clear repeat',
    'Still current',
    'Fading',
    'Changed',
    'Softened',
    'Corrected',
    'Not enough evidence',
  ];

  static const bannedPhrasePrefixes = [
    'you always',
    'this means',
    'your pattern is',
    'you have a deep fear of',
  ];

  static const bannedPhraseSubstrings = [
    'you always ',
    'this means ',
    'your pattern is ',
    'you have a deep fear of ',
  ];

  /// Returns true when [text] uses banned comparison framing.
  static bool violatesBannedPhrase(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return false;
    for (final prefix in bannedPhrasePrefixes) {
      if (lower.startsWith(prefix)) return true;
    }
    for (final phrase in bannedPhraseSubstrings) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  /// Strips banned phrasing; returns [fallback] when unsafe or empty.
  static String sanitizeLine(String text, {required String fallback}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || violatesBannedPhrase(trimmed)) return fallback;
    return trimmed;
  }
}
