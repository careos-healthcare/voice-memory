/// One chapter line prepared for a quiet share card.
class EmotionalChapterShare {
  const EmotionalChapterShare({
    required this.id,
    required this.line,
    this.beforeLabel,
    this.nowLabel,
  });

  final String id;
  final String line;
  final String? beforeLabel;
  final String? nowLabel;

  static const forbiddenPhrases = <String>[
    'healing journey',
    'best self',
    'growth journey',
    'level up',
    'inspirational',
    'motivational',
    'go viral',
  ];

  /// Quiet sharing rejects counts and promotional phrasing.
  static bool isQuiet(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 160) return false;
    final lower = trimmed.toLowerCase();
    for (final phrase in forbiddenPhrases) {
      if (lower.contains(phrase)) return false;
    }
    if (RegExp(
      r'\b\d+\s*(days?|hours?|percent|%)\b',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return false;
    }
    return true;
  }

  bool get canShare => isQuiet(line);
}
