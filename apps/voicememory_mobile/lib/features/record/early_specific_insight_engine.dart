import '../../models/journal_entry.dart';
import '../../product/consumer_copy_guard.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_repeat_phrase_sanitizer.dart';
import 'early_specific_insight_copy.dart';
import 'early_specific_insight_model.dart';

/// Deterministic early compare insight from the latest 2–3 saved moments.
class EarlySpecificInsightEngine {
  const EarlySpecificInsightEngine();

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
    'said',
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
    'work pressure',
    'overthinking',
  ];

  /// Returns a phrase present in [current] and at least one prior entry.
  ///
  /// Shared by immediate and early-archive surfaces so recurrence claims use
  /// one detector and can never be inferred from the current entry alone.
  String? exactSharedPhrase({
    required JournalEntry current,
    required List<JournalEntry> priorEntries,
  }) {
    final currentText = _entryText(current);
    if (currentText.isEmpty) return null;
    final priorTexts = priorEntries
        .map(_entryText)
        .where((text) => text.isNotEmpty);
    final texts = [currentText, ...priorTexts];
    if (texts.length < 2) return null;
    final phrases = _bestSharedPhrases(texts, maxPhrases: 1);
    if (phrases.isEmpty) return null;
    final phrase = phrases.first;
    final matchesPrior = priorTexts.any(
      (text) => text.toLowerCase().contains(phrase),
    );
    return matchesPrior && currentText.toLowerCase().contains(phrase)
        ? _displayPhrase(phrase)
        : null;
  }

  EarlySpecificInsight build(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return EarlySpecificInsight.none;

    final window = eligible.length <= 3
        ? eligible
        : eligible.sublist(eligible.length - 3);
    final texts = window.map(_entryText).where((t) => t.isNotEmpty).toList();
    if (texts.length < 2) return EarlySpecificInsight.none;

    final shared = _bestSharedPhrases(texts, maxPhrases: 2);
    if (shared.isEmpty) return EarlySpecificInsight.none;

    final primary = shared.first;
    final secondary = shared.length > 1 ? shared[1] : null;
    final evidenceQuotes = _evidenceQuotes(texts, shared);
    if (evidenceQuotes.length < 2 && shared.length == 1) {
      final single = _quoteAround(
        texts.firstWhere(
          (t) => t.toLowerCase().contains(primary),
          orElse: () => texts.first,
        ),
        primary,
      );
      if (single == null) return EarlySpecificInsight.none;
    }

    final oneLinePattern = _patternLine(primary, secondary, texts);
    final evidenceLine = _evidenceLine(evidenceQuotes);
    final nextQuestion = _nextQuestion(primary, secondary, texts);
    final confidenceLabel = 'Early signal — based on ${texts.length} moments';

    final insight = EarlySpecificInsight(
      title: EarlySpecificInsightCopy.sharpTitle,
      oneLinePattern: oneLinePattern,
      evidenceLine: evidenceLine,
      nextQuestion: nextQuestion,
      confidenceLabel: confidenceLabel,
      shouldShow: true,
    );

    if (!_isSafeCopy(insight)) return EarlySpecificInsight.none;
    return insight;
  }

  String _entryText(JournalEntry entry) {
    final parts = <String>[
      ?ConsumerCopyGuard.userFacingObservation(
        entry.reflection.concreteObservation,
      ),
      ?ConsumerCopyGuard.userFacingObservation(
        entry.reflection.exactLanguagePattern,
      ),
      ?_cleanTranscript(entry.transcript),
    ];
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _cleanTranscript(String transcript) {
    final line = transcript.split('\n').first.trim();
    if (line.isEmpty || line.startsWith('[draft]')) return null;
    if (ConsumerCopyGuard.isSystemObservation(line)) return null;
    return line;
  }

  List<String> _bestSharedPhrases(
    List<String> texts, {
    required int maxPhrases,
  }) {
    final lowerTexts = texts.map((t) => t.toLowerCase()).toList();
    final priority = <String>[];
    for (final phrase in _priorityPhrases) {
      if (lowerTexts.every((t) => t.contains(phrase))) {
        priority.add(phrase);
        if (priority.length >= maxPhrases) return priority;
      }
    }
    if (priority.isNotEmpty) return priority;

    final counts = <String, Set<int>>{};
    for (var i = 0; i < texts.length; i++) {
      for (final phrase in _phrasesIn(texts[i])) {
        counts.putIfAbsent(phrase, () => <int>{}).add(i);
      }
    }

    final ranked =
        counts.entries
            .where((e) => e.value.length >= 2)
            .where((e) => !_isGenericPhrase(e.key))
            .where((e) => !_isWeakNgram(e.key))
            .where((e) => !ArchiveRepeatPhraseSanitizer.isLowQuality(e.key))
            .map(
              (e) => MapEntry(e.key, e.value.length * e.key.split(' ').length),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return ArchiveRepeatPhraseSanitizer.dedupeNearIdentical(
      ranked.take(maxPhrases * 2).map((e) => e.key).toList(),
    ).take(maxPhrases).toList();
  }

  Iterable<String> _phrasesIn(String text) sync* {
    final words = _normalizedWords(text);
    for (var size = 4; size >= 2; size--) {
      for (var i = 0; i <= words.length - size; i++) {
        final slice = words.sublist(i, i + size);
        if (slice.every((w) => _stopWords.contains(w))) continue;
        if (slice.first.length < 2 || slice.last.length < 2) continue;
        yield slice.join(' ');
      }
    }
  }

  List<String> _normalizedWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
  }

  bool _isGenericPhrase(String phrase) {
    final lower = phrase.toLowerCase();
    if (lower.length < 5) return true;
    final words = lower.split(' ');
    if (words.every(_stopWords.contains)) return true;
    const genericOnly = {'work', 'today', 'moment', 'thing', 'things', 'time'};
    if (words.length == 1 && genericOnly.contains(words.single)) return true;
    return false;
  }

  bool _isWeakNgram(String phrase) {
    if (ArchiveRepeatPhraseSanitizer.isLowQuality(phrase)) return true;
    final words = phrase.split(' ');
    if (words.length < 2) return true;
    if (_stopWords.contains(words.first) &&
        !_priorityPhrases.contains(phrase)) {
      return true;
    }
    if (_stopWords.contains(words.last) && words.last.length <= 3) {
      return true;
    }
    return ArchiveRepeatPhraseSanitizer.endsWithConnector(phrase);
  }

  String _patternLine(String primary, String? secondary, List<String> texts) {
    final shared = ArchiveRepeatPhraseSanitizer.dedupeNearIdentical([
      primary,
      ?secondary,
    ]);
    final lowerConfidence =
        shared.isEmpty ||
        shared.every(ArchiveRepeatPhraseSanitizer.isLowQuality);
    return ArchiveRepeatPhraseSanitizer.buildRepeatSummary(
      texts: texts,
      sharedPhrases: shared,
      lowerConfidence: lowerConfidence,
    );
  }

  String _displayPhrase(String phrase) {
    return ArchiveRepeatPhraseSanitizer.sanitize(phrase);
  }

  List<String> _evidenceQuotes(List<String> texts, List<String> phrases) {
    final quotes = <String>[];
    for (final phrase in phrases) {
      for (final text in texts) {
        final quote = _quoteAround(text, phrase);
        if (quote == null) continue;
        if (quotes.any((q) => q.toLowerCase() == quote.toLowerCase())) continue;
        quotes.add(quote);
        break;
      }
    }
    return quotes;
  }

  String _evidenceLine(List<String> quotes) {
    return ArchiveRepeatPhraseSanitizer.buildEvidenceLine(quotes);
  }

  String? _quoteAround(String text, String phrase) {
    final lower = text.toLowerCase();
    final index = lower.indexOf(phrase);
    if (index < 0) return null;
    return text.substring(index, index + phrase.length).trim();
  }

  String _nextQuestion(String primary, String? secondary, List<String> texts) {
    final blob = '$primary ${secondary ?? ''} ${texts.join(' ')}'.toLowerCase();
    if (blob.contains('wanted to say no') || blob.contains('want to say no')) {
      return 'Tomorrow, notice the moment before you agree to something.';
    }
    if (blob.contains('said yes') ||
        blob.contains('no capacity') ||
        blob.contains('before you agree')) {
      return 'Tomorrow, notice if this shows up before you agree to something.';
    }
    if (blob.contains('work') &&
        (blob.contains('pressure') || blob.contains('deadline'))) {
      return 'Tomorrow, notice whether work pressure shows up in what you say first.';
    }
    if (blob.contains('overthink') || blob.contains('overthinking')) {
      return 'Tomorrow, notice when your mind starts replaying the same loop.';
    }
    if (blob.contains('avoid')) {
      return 'Tomorrow, notice what you keep putting off until later.';
    }
    return 'Tomorrow, notice if "${_displayPhrase(primary)}" shows up again.';
  }

  bool _isSafeCopy(EarlySpecificInsight insight) {
    final blob =
        '${insight.title} ${insight.oneLinePattern} ${insight.evidenceLine} '
                '${insight.nextQuestion} ${insight.confidenceLabel}'
            .toLowerCase();
    for (final banned in EarlySpecificInsightCopy.bannedTerms) {
      if (_containsBannedTerm(blob, banned)) return false;
    }
    return insight.oneLinePattern.isNotEmpty &&
        insight.evidenceLine.isNotEmpty &&
        insight.nextQuestion.isNotEmpty;
  }

  bool _containsBannedTerm(String blob, String term) {
    final trimmed = term.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    if (trimmed == 'ai') {
      return RegExp(r'\bai\b', caseSensitive: false).hasMatch(blob);
    }
    // Escape special chars and evaluate word boundaries safely
    final escaped = RegExp.escape(trimmed);
    return RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(blob);
  }
}
