import 'belief_distance_model.dart';
import 'pressure_check_in_record.dart';

/// Surfaces a belief-like phrase that repeated in the user's own saved
/// notes — pure and deterministic, no AI calls.
///
/// Extraction rules:
/// - Only the user's exact words from saved notes (fear / stop-cost note);
///   transcripts, contexts, and option tags are never turned into phrases.
/// - A phrase qualifies only when its language genuinely repeated: it must
///   contain a meaningful word that appears in the notes of at least
///   [BeliefDistance.minRelatedEntries] separate entries.
/// - First-person pressure phrases ("I have to…", "I cannot…",
///   "stopping is…") are preferred over plain descriptions.
/// - Normalized lightly: surrounding punctuation is trimmed and one short
///   sentence is taken verbatim from a longer note — the user's wording is
///   preserved, never rewritten.
/// - If no phrase can be safely formed, nothing is shown. Never fabricated.
class BeliefDistanceEngine {
  const BeliefDistanceEngine();

  /// Filler plus generic app words — a belief named after these would read
  /// like template copy, not the user's own repeated language.
  static const Set<String> _ignoredWords = {
    'the', 'and', 'for', 'that', 'this', 'with', 'was', 'were', 'will',
    'would', 'wont', "won't", 'its', "it's", 'not', 'but', 'had', 'have',
    'has', 'did', 'does', 'about', 'from', 'they', 'them', 'when', 'then',
    'than', 'what', 'how', 'why', 'who', 'all', 'too', 'very', 'just',
    'like', 'get', 'got', 'gets', 'into', 'out', 'off', 'might', 'maybe',
    'could', 'should', 'because', 'being', 'been', 'still', 'even', 'more',
    'again', 'myself', 'dont', "don't", 'cant', "can't", 'ill', "i'll",
    'pressure', 'moment', 'moments', 'pattern', 'patterns', 'archive',
    'entry', 'entries', 'check', 'checkin', 'app', 'archiveme', 'feel',
    'feels', 'felt', 'feeling', 'today', 'yesterday', 'tomorrow',
  };

  BeliefDistance build(List<PressureCheckInRecord> records) {
    if (records.length < BeliefDistance.minRelatedEntries) {
      return BeliefDistance.none();
    }

    // Meaningful note words → the entries they appeared in (once per entry).
    final wordEntries = <String, List<PressureCheckInRecord>>{};
    for (final record in records) {
      for (final word in _noteWords(record)) {
        wordEntries.putIfAbsent(word, () => []).add(record);
      }
    }

    // Repeated pressure language only: words present in 2+ entries' notes,
    // strongest repetition first.
    final repeatedWords = wordEntries.entries
        .where((e) => e.value.length >= BeliefDistance.minRelatedEntries)
        .toList()
      ..sort((a, b) {
        final byCount = b.value.length.compareTo(a.value.length);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    if (repeatedWords.isEmpty) return BeliefDistance.none();

    for (final entry in repeatedWords) {
      final word = entry.key;
      final related = [...entry.value]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final phrase = _phraseFor(word, related);
      if (phrase == null) continue;
      return _build(word, phrase, related);
    }
    return BeliefDistance.none();
  }

  BeliefDistance _build(
    String word,
    String phrase,
    List<PressureCheckInRecord> related,
  ) {
    final count = related.length;
    final quoted = phrase.endsWith('.')
        ? phrase.substring(0, phrase.length - 1)
        : phrase;

    return BeliefDistance(
      hasBelief: true,
      title: count >= 3
          ? BeliefDistance.defaultTitle
          : BeliefDistance.cautiousTitle,
      beliefLine: '\u201C$quoted\u201D showed up again.',
      frequencyLine: 'This appeared $count times in your recent archive.',
      evidenceSnippets: _snippets(word, related),
      sourceTerms: _sourceTerms(word, phrase),
      entryIds: related.map((r) => r.entryId).toList(),
      confidenceLabel: _confidenceLabel(count),
    );
  }

  /// First-person pressure markers that make a note read like a belief.
  static const List<String> _beliefMarkers = [
    'i have to',
    'i need to',
    'i cannot',
    "i can't",
    'i cant',
    'i fall behind',
    'i am behind',
    "i'm behind",
    'stopping feels',
    'stopping is',
  ];

  /// The phrase that carries the repeated word — the user's exact text,
  /// never rewritten. Belief-marker phrases win; otherwise the newest short
  /// note that holds the repeated word.
  String? _phraseFor(String word, List<PressureCheckInRecord> related) {
    for (final requireMarker in const [true, false]) {
      for (final record in related.reversed) {
        for (final text in [record.fear, record.stopCostNote]) {
          final phrase = _candidatePhrase(text, word);
          if (phrase == null) continue;
          if (requireMarker && !_hasBeliefMarker(phrase)) continue;
          return phrase;
        }
      }
    }
    return null;
  }

  /// One short phrase from a note, normalized lightly: when a note holds
  /// several sentences, the exact sentence carrying the repeated word is
  /// used; surrounding punctuation is trimmed. Anything still longer than
  /// [BeliefDistance.maxPhraseLength] is skipped, never cut mid-thought.
  String? _candidatePhrase(String? text, String word) {
    final note = text?.trim() ?? '';
    if (note.isEmpty) return null;
    for (final sentence in note.split(RegExp(r'[.!?\u2026]+\s*'))) {
      final phrase = sentence
          .replaceAll(RegExp(r'^[\s,;:\u2013\u2014-]+|[\s,;:\u2013\u2014-]+$'), '');
      if (phrase.isEmpty || phrase.length > BeliefDistance.maxPhraseLength) {
        continue;
      }
      if (_words(phrase).contains(word)) return phrase;
    }
    return null;
  }

  bool _hasBeliefMarker(String phrase) {
    final lower = phrase.toLowerCase();
    return _beliefMarkers.any(lower.contains);
  }

  /// Exact note texts behind the belief, newest first, capped and deduped.
  List<String> _snippets(String word, List<PressureCheckInRecord> related) {
    final snippets = <String>[];
    final seen = <String>{};
    for (final record in related.reversed) {
      for (final text in [record.fear, record.stopCostNote]) {
        final snippet = text?.trim() ?? '';
        if (snippet.isEmpty || !_words(snippet).contains(word)) continue;
        if (snippets.length >= BeliefDistance.maxSnippets) return snippets;
        if (seen.add(snippet.toLowerCase())) snippets.add(snippet);
      }
    }
    return snippets;
  }

  /// Meaningful words of the quoted phrase itself, primary word first.
  List<String> _sourceTerms(String word, String phrase) {
    final terms = <String>[word];
    for (final other in _words(phrase)) {
      if (terms.length >= BeliefDistance.maxTerms) break;
      if (other != word) terms.add(other);
    }
    return terms;
  }

  String _confidenceLabel(int count) {
    if (count >= 5) return BeliefDistance.strongRepeatedSignalConfidence;
    if (count >= 3) return BeliefDistance.repeatedSignalConfidence;
    return BeliefDistance.earlySignalConfidence;
  }

  /// Distinct meaningful words in one entry's notes — counted once per entry
  /// so one wordy note cannot fake repetition.
  Set<String> _noteWords(PressureCheckInRecord record) =>
      _words('${record.fear ?? ''} ${record.stopCostNote ?? ''}');

  Set<String> _words(String text) {
    final words = <String>{};
    for (final raw in text.toLowerCase().split(RegExp(r"[^a-z']+"))) {
      final word = raw.trim();
      if (word.length < 3 || _ignoredWords.contains(word)) continue;
      words.add(word);
    }
    return words;
  }
}
