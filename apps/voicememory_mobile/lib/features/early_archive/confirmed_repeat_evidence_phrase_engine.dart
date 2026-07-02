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
  static const maxWords = 6;
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
    'stress',
    'confidence',
    'procrastination',
    'perfectionism',
    'overthinking',
    'fear',
    'people pleasing',
    'people-pleasing',
  };

  static const _concreteActionPatterns = [
    'said yes again',
    'said yes when',
    'said yes',
    'still agreed',
    'checked again',
    'checking again',
    'checked the message again',
    'checked the message',
    'checked one more time',
    'checked one more',
    'went back and checked',
    'went back',
    'avoided the message',
    'avoided the',
    'avoided replying',
    'paused before replying',
    'paused before',
    'walked outside',
    "couldn't stop thinking",
    'couldnt stop thinking',
    'put it off',
    'asked for reassurance',
    'no capacity',
    'checking my phone',
    'going back to it',
  ];

  static const _actionVerbHints = {
    'agreed',
    'asked',
    'avoided',
    'back',
    'checked',
    'checking',
    'kept',
    'paused',
    'put',
    'replied',
    'said',
    'stopped',
    'walked',
    'thinking',
    'went',
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

  static ConfirmedRepeatEvidenceResult extract(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return ConfirmedRepeatEvidenceResult.empty;

    final window =
        eligible.length <= 3 ? eligible : eligible.sublist(0, 3);
    final texts = window.map(_entryText).where((t) => t.isNotEmpty).toList();
    if (texts.length < 2) return ConfirmedRepeatEvidenceResult.empty;

    final rawPhrases = _extractPhrases(texts);
    final phrases = _rankPhrases(
      groundedPhrases(rawPhrases, window),
      texts,
    );
    final isStrong = _isStrongEvidence(phrases, texts);
    return ConfirmedRepeatEvidenceResult(
      phrases: phrases,
      isStrong: isStrong,
    );
  }

  /// Phrases that are concrete, user-written, and not generic psychology labels.
  static List<String> groundedPhrases(
    List<String> phrases,
    List<JournalEntry> entries,
  ) {
    final texts = ArchiveEvidenceGuard.eligibleEntries(entries)
        .map(_entryText)
        .where((text) => text.isNotEmpty)
        .toList();
    return _rankPhrases(
      phrases
          .where(
            (phrase) =>
                isConcretePhrase(phrase) &&
                !isAbstractOnlyPhrase(phrase) &&
                !usesUngroundedGenericLabel(label: phrase, entries: entries),
          )
          .toList(),
      texts,
    );
  }

  static List<String> _rankPhrases(List<String> phrases, List<String> texts) {
    final ranked = [...phrases]
      ..sort(
        (a, b) => _phraseRank(b, texts).compareTo(_phraseRank(a, texts)),
      );
    return ranked;
  }

  static int _phraseRank(String phrase, List<String> texts) {
    var score = _phraseScore(phrase);
    final lower = phrase.toLowerCase();
    if (_concreteActionPatterns.any(lower.contains)) score += 30;
    if (_appearsInMultipleTexts(phrase, texts)) score += 24;
    return score;
  }

  /// First concrete phrase from one moment — for next-moment guidance at entry 1.
  static String? singleEntryConcretePhrase(JournalEntry entry) {
    final text = _entryText(entry);
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();
    String? bestPattern;
    var bestPatternScore = -1;
    for (final pattern in _concreteActionPatterns) {
      if (!lower.contains(pattern)) continue;
      final display = _displayFromEntries([text], pattern);
      if (display == null) continue;
      if (!_isConcretePhrase(display) || _isAbstractOnlyPhrase(display)) {
        continue;
      }
      if (usesUngroundedGenericLabel(label: display, entries: [entry])) {
        continue;
      }
      final score = _phraseScore(display);
      if (score > bestPatternScore) {
        bestPatternScore = score;
        bestPattern = display;
      }
    }
    if (bestPattern != null) return bestPattern;

    final candidates = <String, int>{};
    for (final phrase in _phrasesIn(text)) {
      if (_isWeakPhrase(phrase)) continue;
      if (!_isConcretePhrase(phrase)) continue;
      if (_isAbstractOnlyPhrase(phrase)) continue;
      if (ArchiveRepeatPhraseSanitizer.isLowQuality(phrase)) continue;
      final display = _displayFromEntries([text], phrase);
      if (display == null) continue;
      if (usesUngroundedGenericLabel(label: display, entries: [entry])) {
        continue;
      }
      final key = display.toLowerCase();
      final score = _phraseScore(display);
      final existing = candidates[key];
      if (existing == null || score > existing) {
        candidates[key] = score;
      }
    }
    if (candidates.isEmpty) return null;

    final ranked = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in ranked) {
      final display = _displayFromEntries([text], entry.key);
      if (display != null) return display;
    }
    return null;
  }

  /// Shared concrete phrase across two moments — for next-moment guidance at entry 2.
  static String? sharedConcretePhrase(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return null;

    for (final phrase in groundedPhrases(extract(eligible).phrases, eligible)) {
      return phrase;
    }
    return null;
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

  static bool isConcretePhrase(String phrase) => _isConcretePhrase(phrase);

  static bool isAbstractOnlyPhrase(String phrase) => _isAbstractOnlyPhrase(phrase);

  static bool _isStrongEvidence(List<String> phrases, List<String> texts) {
    if (phrases.isEmpty) return false;
    if (phrases.every(_isAbstractOnlyPhrase)) return false;
    if (!phrases.any(_isConcretePhrase)) return false;

    final crossEntry = phrases
        .where((phrase) => _appearsInMultipleTexts(phrase, texts))
        .toList();
    if (crossEntry.isEmpty) return false;

    if (crossEntry.length >= minPhrasesForStrong) return true;
    return crossEntry.any(_isConcretePhrase);
  }

  static bool _appearsInMultipleTexts(String phrase, List<String> texts) {
    final lower = phrase.toLowerCase();
    var count =
        texts.where((text) => text.toLowerCase().contains(lower)).length;
    if (count >= 2) return true;

    final words =
        lower.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.length < 2) return false;
    if (!_actionVerbHints.contains(words.first)) return false;

    count = texts.where((text) {
      final blob = text.toLowerCase();
      return words.every(blob.contains);
    }).length;
    return count >= 2;
  }

  static List<String> _extractPhrases(List<String> texts) {
    final lowerTexts = texts.map((t) => t.toLowerCase()).toList();
    final candidates = <String, int>{};

    void addCandidate(String phrase, {required int bonus}) {
      final display =
          _displayFromEntries(texts, phrase) ?? _displayActionPattern(texts, phrase);
      if (display == null) return;
      if (_isAbstractOnlyPhrase(display) && !_isConcretePhrase(display)) return;
      final key = display.toLowerCase();
      final score =
          bonus + _phraseScore(display) + _crossEntryVerbBonus(display, lowerTexts);
      final existing = candidates[key];
      if (existing == null || score > existing) {
        candidates[key] = score;
      }
    }

    for (final phrase in _concreteActionPatterns) {
      if (_appearsInMultipleTexts(phrase, texts)) {
        addCandidate(phrase, bonus: 24);
      } else if (lowerTexts.any((t) => t.contains(phrase))) {
        addCandidate(phrase, bonus: 10);
      }
    }

    final ngramCounts = <String, Set<int>>{};
    for (var i = 0; i < texts.length; i++) {
      for (final phrase in _phrasesIn(texts[i])) {
        ngramCounts.putIfAbsent(phrase, () => <int>{}).add(i);
      }
    }

    for (final entry in ngramCounts.entries) {
      if (entry.value.length < 2) continue;
      if (_isWeakPhrase(entry.key)) continue;
      if (!_isConcretePhrase(entry.key)) continue;
      if (ArchiveRepeatPhraseSanitizer.isLowQuality(entry.key)) continue;
      if (_concreteActionPatterns.any(entry.key.contains)) continue;
      addCandidate(
        entry.key,
        bonus: entry.value.length * entry.key.split(' ').length * 2,
      );
    }

    final ranked = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final kept = <String>[];
    for (final entry in ranked) {
      final display = _displayFromEntries(texts, entry.key);
      if (display == null) continue;
      if (kept.any((k) => k.toLowerCase() == display.toLowerCase())) continue;
      kept.add(display);
      if (kept.length >= maxPhrases) break;
    }

    return kept;
  }

  static int _crossEntryVerbBonus(String phrase, List<String> lowerTexts) {
    final lower = phrase.toLowerCase();
    var bonus = 0;
    for (final verb in _actionVerbHints) {
      if (!lower.contains(verb)) continue;
      final count = lowerTexts.where((text) => text.contains(verb)).length;
      if (count >= 2) bonus += 6;
    }
    return bonus;
  }

  static int _phraseScore(String phrase) {
    var score = 0;
    if (_isConcretePhrase(phrase)) score += 12;
    if (_isAbstractOnlyPhrase(phrase)) score -= 14;
    final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words >= 2 && words <= 4) score += 5;
    if (words > 6) score -= 8;
    return score;
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

  static bool _isWeakPhrase(String phrase) {
    if (_isAbstractOnlyPhrase(phrase)) return true;
    final lower = phrase.toLowerCase();
    if (lower.length < 5) return true;
    final words = lower.split(' ');
    if (words.every(_stopWords.contains)) return true;
    const genericOnly = {
      'work',
      'today',
      'moment',
      'thing',
      'things',
      'time',
      'busy',
    };
    if (words.length == 1 && genericOnly.contains(words.single)) return true;
    return false;
  }

  static bool _isConcretePhrase(String phrase) {
    final lower = phrase.toLowerCase();
    for (final pattern in _concreteActionPatterns) {
      if (lower.contains(pattern)) return true;
    }
    final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.any(_actionVerbHints.contains);
  }

  static bool _isAbstractOnlyPhrase(String phrase) {
    final lower = phrase.toLowerCase();
    final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return true;

    if (words.length == 1 && bannedGenericLabels.contains(words.single)) {
      return true;
    }

    if (_isConcretePhrase(phrase)) return false;

    final hasAbstract = bannedGenericLabels.any(lower.contains);
    if (!hasAbstract) {
      const vagueOnly = {
        'busy',
        'stretched',
        'thin',
        'felt',
        'feeling',
        'work',
        'office',
        'day',
        'again',
        'unsettled',
      };
      return words.every(
        (word) => vagueOnly.contains(word) || _stopWords.contains(word),
      );
    }

    return true;
  }

  static String? _displayActionPattern(List<String> texts, String pattern) {
    if (!_appearsInMultipleTexts(pattern, texts)) return null;
    final words =
        pattern.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty || words.length > maxWords) return null;

    for (final text in texts) {
      final lower = text.toLowerCase();
      if (!words.every(lower.contains)) continue;
      final display = _displayFromEntries(texts, pattern);
      return display ?? pattern;
    }
    return null;
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
      if (_isWeakPhrase(slice)) continue;
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
