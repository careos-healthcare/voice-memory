import 'legacy_pattern_copy_guard.dart';
import 'pattern_copy_quality_gate.dart';

/// Pulls repeated meaningful words/phrases from user transcripts.
abstract class TranscriptEvidenceExtractor {
  TranscriptEvidenceExtractor._();

  static const _candidatePhrases = [
    'correct standard',
    'work properly',
    'get things right',
    'need this to work',
    'make this work',
    'making it work',
    'get it right',
    'getting it right',
    'falling behind',
    'feel behind',
    'fall behind',
    'pressure to get things right',
    'pressure to get it right',
    'pressure to finish',
    'pressure to make',
    'pressure',
    'properly',
    'standard',
    'works',
    'work',
    'finish',
    'should',
    'crash',
    'test',
  ];

  static const _shortAllowlist = {
    'work',
    'works',
    'test',
    'crash',
    'should',
    'finish',
    'pressure',
    'standard',
    'properly',
  };

  static bool isShortEvidenceWord(String phrase) =>
      _shortAllowlist.contains(phrase.trim().toLowerCase());

  static List<String> phrasesInText(String transcript, {int maxPhrases = 4}) {
    final lower = transcript.trim().toLowerCase();
    if (lower.isEmpty) return const [];

    final hits = <String>[];
    for (final candidate in _candidatePhrases) {
      if (!lower.contains(candidate)) continue;
      if (hits.any((existing) => existing.toLowerCase().contains(candidate))) {
        continue;
      }
      final display = _displayFromTranscripts(candidate, [transcript]);
      if (!_isDisplayablePhrase(display)) continue;
      hits.add(display);
      if (hits.length >= maxPhrases) break;
    }
    return hits;
  }

  static List<String> extractRepeatedPhrases(
    List<String> transcripts, {
    int minEntryHits = 2,
    int maxPhrases = 4,
  }) {
    if (transcripts.length < 2) return const [];

    final normalized = transcripts
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    if (normalized.length < 2) return const [];

    final entryHits = <String, int>{};
    for (final candidate in _candidatePhrases) {
      var hits = 0;
      for (final text in normalized) {
        if (text.contains(candidate)) hits++;
      }
      if (hits >= minEntryHits) {
        entryHits[candidate] = hits;
      }
    }

    if (entryHits.isEmpty) return const [];

    final ranked = entryHits.keys.toList()
      ..sort((a, b) {
        final lengthCompare = b.length.compareTo(a.length);
        if (lengthCompare != 0) return lengthCompare;
        return (entryHits[b] ?? 0).compareTo(entryHits[a] ?? 0);
      });

    final kept = <String>[];
    for (final candidate in ranked) {
      if (kept.any((existing) => existing.toLowerCase().contains(candidate))) {
        continue;
      }
      final display = _displayFromTranscripts(candidate, transcripts);
      if (!_isDisplayablePhrase(display)) continue;
      kept.add(display);
      if (kept.length >= maxPhrases) break;
    }

    return kept;
  }

  static bool hasPressureWorkTheme(List<String> phrases) {
    const signals = [
      'pressure',
      'work',
      'works',
      'properly',
      'standard',
      'right',
      'finish',
      'should',
      'make this work',
      'need this to work',
    ];
    final blob = phrases.join(' ').toLowerCase();
    return signals.any(blob.contains);
  }

  static String _displayFromTranscripts(String candidate, List<String> transcripts) {
    final lowerCandidate = candidate.toLowerCase();
    for (final transcript in transcripts) {
      final lower = transcript.toLowerCase();
      final index = lower.indexOf(lowerCandidate);
      if (index < 0) continue;
      final end = index + candidate.length;
      if (end <= transcript.length) {
        return transcript.substring(index, end).trim();
      }
    }
    return candidate;
  }

  static bool _isDisplayablePhrase(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return false;
    if (LegacyPatternCopyGuard.containsLegacyCopy(trimmed)) return false;

    final lower = trimmed.toLowerCase();
    if (_shortAllowlist.contains(lower)) return true;

    return PatternCopyQualityGate.gatePhraseOrNull(trimmed) != null;
  }
}
