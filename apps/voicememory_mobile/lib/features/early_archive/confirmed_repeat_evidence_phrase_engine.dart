import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_repeat_phrase_sanitizer.dart';
import '../timeline/timeline_entry_display.dart';

/// Grounded evidence phrases pulled from matched entries — never invented.
class ConfirmedRepeatEvidenceResult {
  const ConfirmedRepeatEvidenceResult({
    required this.phrases,
    required this.isStrong,
  });

  final List<String> phrases;
  final bool isStrong;

  static const empty =
      ConfirmedRepeatEvidenceResult(phrases: [], isStrong: false);
}

/// Extracts 2–3 short phrases from the user's own words for repeat proof.
abstract final class ConfirmedRepeatEvidencePhraseEngine {
  ConfirmedRepeatEvidencePhraseEngine._();

  static const minWords = 2;
  static const maxWords = 8;
  static const minPhrasesForStrong = 2;
  static const maxPhrases = 3;

  static const bannedGenericLabels = {
    'control',
    'uncertainty',
    'avoidance',
    'overwhelm',
    'anxiety',
    'self-sabotage',
    'self sabotage',
  };

  static const _stopWords = {
    'about',
    'after',
    'again',
    'also',
    'been',
    'before',
    'could',
    'even',
    'from',
    'had',
    'have',
    'just',
    'like',
    'more',
    'much',
    'really',
    'some',
    'that',
    'the',
    'then',
    'there',
    'they',
    'this',
    'today',
    'very',
    'was',
    'were',
    'what',
    'when',
    'with',
    'would',
    'your',
  };

  static const _priorityPhrases = [
    'said yes again',
    'said yes when',
    'said yes',
    'no capacity',
    'checking again',
    'checking my phone',
    'felt uncertain',
    'feel uncertain',
    'not feeling done',
    'going back to it',
    'work pressure',
    'overthinking',
  ];

  static ConfirmedRepeatEvidenceResult extract(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return ConfirmedRepeatEvidenceResult.empty;

    final window = eligible.length <= 3
        ? eligible
        : eligible.sublist(0, 3);
    final texts = window.map(_entryText).where((t) => t.isNotEmpty).toList();
    if (texts.length < 2) return ConfirmedRepeatEvidenceResult.empty;

    final phrases = _extractPhrases(texts);
    return ConfirmedRepeatEvidenceResult(
      phrases: phrases,
      isStrong: phrases.length >= minPhrasesForStrong,
    );
  }

  /// True when a label uses generic psychology language not present in entries.
  static bool usesUngroundedGenericLabel({
    required String label,
    required List<JournalEntry> entries,
  }) {
    final blob = ArchiveEvidenceGuard.eligibleEntries(entries)
        .map(_entryText)
        .join(' ')
        .toLowerCase();
    final lower = label.toLowerCase();
    for (final term in bannedGenericLabels) {
      if (lower.contains(term) && !blob.contains(term)) {
        return true;
      }
    }
    return false;
  }

  static List<String> _extractPhrases(List<String> texts) {
    final lowerTexts = texts.map((t) => t.toLowerCase()).toList();
    final candidates = <String>[];

    for (final phrase in _priorityPhrases) {
      if (lowerTexts.where((t) => t.contains(phrase)).length >= 2) {
        final display = _displayFromEntries(texts, phrase);
        if (display != null) candidates.add(display);
      }
    }

    final ngramCounts = <String, Set<int>>{};
    for (var i = 0; i < texts.length; i++) {
      for (final phrase in _phrasesIn(texts[i])) {
        ngramCounts.putIfAbsent(phrase, () => <int>{}).add(i);
      }
    }

    final ranked = ngramCounts.entries
        .where((e) => e.value.length >= 2)
        .where((e) => !_isGenericPhrase(e.key))
        .where((e) => !ArchiveRepeatPhraseSanitizer.isLowQuality(e.key))
        .map(
          (e) => MapEntry(
            e.key,
            e.value.length * e.key.split(' ').length,
          ),
        )
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in ranked) {
      final display = _displayFromEntries(texts, entry.key);
      if (display == null) continue;
      if (candidates.any((c) => c.toLowerCase() == display.toLowerCase())) {
        continue;
      }
      candidates.add(display);
    }

    final deduped = ArchiveRepeatPhraseSanitizer.dedupeNearIdentical(
      candidates.map((p) => p.toLowerCase()).toList(),
    );

    final kept = <String>[];
    for (final normalized in deduped) {
      final display = _displayFromEntries(texts, normalized);
      if (display == null) continue;
      if (kept.any((k) => k.toLowerCase() == display.toLowerCase())) continue;
      kept.add(display);
      if (kept.length >= maxPhrases) break;
    }

    return kept;
  }

  static Iterable<String> _phrasesIn(String text) sync* {
    final words = _normalizedWords(text);
    for (var size = maxWords; size >= minWords; size--) {
      for (var i = 0; i <= words.length - size; i++) {
        final slice = words.sublist(i, i + size);
        if (slice.every(_stopWords.contains)) continue;
        if (slice.first.length < 2 || slice.last.length < 2) continue;
        yield slice.join(' ');
      }
    }
  }

  static List<String> _normalizedWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
  }

  static bool _isGenericPhrase(String phrase) {
    final lower = phrase.toLowerCase();
    if (lower.length < 5) return true;
    final words = lower.split(' ');
    if (words.every(_stopWords.contains)) return true;
    const genericOnly = {'work', 'today', 'moment', 'thing', 'things', 'time'};
    if (words.length == 1 && genericOnly.contains(words.single)) return true;
    for (final term in bannedGenericLabels) {
      if (lower.contains(term)) return true;
    }
    return false;
  }

  static String? _displayFromEntries(List<String> texts, String phraseLower) {
    final normalized = ArchiveRepeatPhraseSanitizer.sanitize(phraseLower);
    if (normalized.isEmpty || ArchiveRepeatPhraseSanitizer.isLowQuality(normalized)) {
      return null;
    }

    for (final text in texts) {
      final index = text.toLowerCase().indexOf(normalized);
      if (index < 0) continue;
      final end = index + normalized.length;
      if (end > text.length) continue;
      final slice = text.substring(index, end).trim();
      final wordCount = slice.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (wordCount < minWords || wordCount > maxWords) continue;
      if (_isGenericPhrase(slice)) continue;
      return slice;
    }
    return null;
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }
}
