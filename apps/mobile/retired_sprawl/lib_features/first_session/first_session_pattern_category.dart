/// First-session pattern categories used by the scoring engine.
enum FirstSessionPatternCategory {
  responsibility,
  worry,
  relationship,
  selfDoubt,
  avoidance,
  burnout,
  fallback,
  lighter,
}

extension FirstSessionPatternCategoryIds on FirstSessionPatternCategory {
  String get id => switch (this) {
    FirstSessionPatternCategory.responsibility => 'responsibility',
    FirstSessionPatternCategory.worry => 'worry',
    FirstSessionPatternCategory.relationship => 'relationship',
    FirstSessionPatternCategory.selfDoubt => 'selfDoubt',
    FirstSessionPatternCategory.avoidance => 'avoidance',
    FirstSessionPatternCategory.burnout => 'burnout',
    FirstSessionPatternCategory.fallback => 'fallback',
    FirstSessionPatternCategory.lighter => 'lighter',
  };
}

FirstSessionPatternCategory? firstSessionPatternCategoryFromId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final c in FirstSessionPatternCategory.values) {
    if (c.id == raw) return c;
  }
  return null;
}

FirstSessionPatternCategory firstSessionPatternCategoryFromIdOrFallback(
  String? raw,
) =>
    firstSessionPatternCategoryFromId(raw) ??
    FirstSessionPatternCategory.fallback;