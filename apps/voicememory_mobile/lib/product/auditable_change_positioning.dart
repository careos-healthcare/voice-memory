/// The single canonical statement of what ArchiveMe is.
///
/// Every primary positioning slot — onboarding, the empty Record state,
/// Changes, the paywall, the marketing source, and both store listings —
/// resolves to one of these three strings. Nothing here may be reworded in
/// place: change it once, and every surface follows.
abstract final class AuditableChangePositioning {
  AuditableChangePositioning._();

  /// The product category. Leads wherever a category is named.
  static const category = 'Auditable personal change.';

  /// The promise. Leads wherever a headline is shown.
  static const primaryPromise =
      'See what repeated. See what changed. Verify it in your own words.';

  /// The full sentence. Leads wherever a paragraph explains the product.
  static const full =
      'A private change ledger that shows exactly what repeated, what '
      'changed, the words proving it, and lets you correct the record.';

  /// App Store subtitle slot — Apple caps this at 30 characters.
  static const appStoreSubtitle = 'Auditable personal change';

  /// Google Play short description slot — capped at 80 characters.
  static const playStoreShortDescription = primaryPromise;

  /// Positioning that must never lead. Each entry is matched against the
  /// primary slots only, so a factual secondary mention of AI still passes.
  static const forbiddenPrimaryHeadlines = <String, String>{
    r'\bAI journal\b': 'AI journal',
    r'\bAI[\s-]powered journal\b': 'AI-powered journal',
    r'\bvoice journal\b': 'voice journal',
    r'\bAI that (?:remembers|knows|understands)\b': 'AI that remembers/knows',
    r'\bAI that learns (?:about )?you\b': 'AI that learns you',
    r'\bpersonali[sz]ed insights?\b': 'personalised insights',
    r'\bpersonal intelligence\b': 'personal intelligence',
    r'\bask your (?:history|archive|past|life) anything\b':
        'ask your history anything',
    r'\blife operating system\b': 'life operating system',
    r'\blife OS\b': 'Life OS',
    r'\b(?:unified |one )?life story\b': 'life story',
    r'\bhidden truths?\b': 'hidden truth',
    r'\btherapy\b': 'therapy',
    r'\btherapist\b': 'therapist',
    r'\bdiagnos(?:is|e|es)\b': 'diagnosis',
    r'\bpersonality (?:analysis|profile|type)\b': 'personality analysis',
    r'\bAI companion\b': 'AI companion',
    r'\bmemory assistant\b': 'memory assistant',
    r'\bsecond brain\b': 'second brain',
  };

  /// All primary slots, keyed by the surface a reader would name.
  static Map<String, String> primarySlots() => {
    'category': category,
    'primary promise': primaryPromise,
    'full positioning': full,
    'App Store subtitle': appStoreSubtitle,
    'Play short description': playStoreShortDescription,
  };

  /// A denial in the same sentence, ahead of the term, means the copy is
  /// disclaiming the positioning rather than leading with it. "ArchiveMe is
  /// not therapy" states a fact; "Therapy in your pocket" is a headline.
  static final _denial = RegExp(
    r"\b(?:not|never|no|without|nor|isn't|aren't|doesn't|don't)\b",
    caseSensitive: false,
  );

  /// Returns the forbidden headline labels a primary slot value trips.
  ///
  /// Matching is sentence-scoped so a denial cannot launder a claim made in a
  /// neighbouring sentence, and a claim cannot be flagged because an unrelated
  /// neighbouring sentence happened to contain the word "not".
  static List<String> forbiddenHeadlinesIn(String value) {
    final hits = <String>[];
    for (final entry in forbiddenPrimaryHeadlines.entries) {
      final pattern = RegExp(entry.key, caseSensitive: false);
      final tripped = _sentences(value).any((sentence) {
        for (final match in pattern.allMatches(sentence)) {
          if (!_denial.hasMatch(sentence.substring(0, match.start))) {
            return true;
          }
        }
        return false;
      });
      if (tripped) hits.add(entry.value);
    }
    return hits;
  }

  static Iterable<String> _sentences(String value) =>
      value.split(RegExp(r'(?<=[.!?])\s+|\n+')).where((s) => s.isNotEmpty);
}
