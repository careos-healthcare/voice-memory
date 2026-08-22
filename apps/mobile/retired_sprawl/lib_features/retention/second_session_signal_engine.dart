import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/comparison_engine/comparison_engine_prompt.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/interpretation/interpretation_quality_engine.dart';
import 'package:archiveme_mobile/features/interpretation/interpretation_read_model.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_model.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';

/// Deterministic second-recording comparison — no network AI.
class SecondSessionSignalEngine {
  const SecondSessionSignalEngine();

  static const _patternEngine = FirstSessionPatternEngine();
  static const _interpretationEngine = InterpretationQualityEngine();
  static const _heuristics = ArchiveEvidenceHeuristics();

  static const _defaultChangeFallback =
      'ArchiveMe is still comparing your saved words.';

  static const _threadStopwords = {
    'something',
    'another',
    'thing',
    'clearly',
    'explain',
  };

  /// True when the latest two moments show a repeat grounded in saved words.
  bool hasGroundedRepeatMatch(List<JournalEntry> entries) {
    final comparison = build(entries);
    if (!comparison.hasEnoughData || !comparison.possibleRepeat) return false;
    return _isGroundedThread(comparison.whatRepeated);
  }

  SecondSessionComparison build(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsEarlyComparisons(entries)) {
      return SecondSessionComparison.insufficient();
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) {
      return SecondSessionComparison.insufficient();
    }

    final previous = eligible[eligible.length - 2];
    final latest = eligible.last;

    final previousPattern = _patternEngine.build(previous);
    final latestPattern = _patternEngine.build(latest);

    final previousRead = _interpretationEngine.build(
      latestEntry: previous,
      patternHint: previousPattern,
    );
    final latestRead = _interpretationEngine.build(
      latestEntry: latest,
      priorEntries: [previous],
      patternHint: latestPattern,
    );

    final previousLabel = _labelFor(previousRead, previousPattern);
    final latestLabel = _labelFor(latestRead, latestPattern);

    final overlap = _overlapScore(
      previousPattern,
      latestPattern,
      previousRead,
      latestRead,
    );
    final previousText = _entryText(previous);
    final latestText = _entryText(latest);
    final userWordOverlap = _hasUserWordOverlap(previousText, latestText);
    final signalOverlap =
        overlap >= 0.45 ||
        previousPattern.categoryId == latestPattern.categoryId ||
        latestRead.archiveRepeatDetected;
    final possibleRepeat = signalOverlap && userWordOverlap;

    if (!possibleRepeat) {
      return SecondSessionComparison(
        hasEnoughData: true,
        title: ConsumerUiCopy.secondSessionPossibleRepeatTitle,
        body: ConsumerUiCopy.secondSessionCompareTemplate
            .replaceAll('{previous}', previousLabel)
            .replaceAll('{latest}', latestLabel),
        whatToTestNext: latestRead.reads.isNotEmpty
            ? latestRead.reads.first.nextEvidencePrompt
            : (latestPattern.watchForText.isNotEmpty
                  ? 'Record once more and notice ${latestPattern.watchForText}.'
                  : 'Record another ordinary moment and notice what feels different.'),
        previousSignalLabel: previousLabel,
        latestSignalLabel: latestLabel,
      );
    }

    final groundedRead = latestRead.reads.isNotEmpty
        ? latestRead.reads.first
        : null;
    final analysis = _heuristics.analyze(eligible);
    final userThread = _userThread(
      previous: previous,
      latest: latest,
      groundedRead: groundedRead,
      analysis: analysis,
    );
    final useFallbackCopy =
        userThread == null || !_isStrongUserThread(userThread);

    final whatRepeated = useFallbackCopy
        ? ConsumerUiCopy.secondSessionFallbackWhatRepeated
        : userThread;
    final whatChanged = useFallbackCopy
        ? ConsumerUiCopy.secondSessionFallbackWhatChanged
        : _userChange(
            previous: previous,
            latest: latest,
            analysis: analysis,
            thread: userThread,
          );

    return SecondSessionComparison(
      hasEnoughData: true,
      title: ConsumerUiCopy.secondSessionPossibleRepeatTitle,
      body: possibleRepeat
          ? ConsumerUiCopy.secondSessionSoundsClose
          : ConsumerUiCopy.secondSessionCompareTemplate
                .replaceAll('{previous}', previousLabel)
                .replaceAll('{latest}', latestLabel),
      whatRepeated: whatRepeated,
      whatChanged: whatChanged,
      whatToTestNext: useFallbackCopy
          ? ConsumerUiCopy.secondSessionFallbackWhatToTestNext
          : (latestRead.reads.isNotEmpty
                ? latestRead.reads.first.nextEvidencePrompt
                : (latestPattern.watchForText.isNotEmpty
                      ? 'Notice ${latestPattern.watchForText} in your next recording.'
                      : 'Record one more moment and see if this repeats.')),
      previousSignalLabel: useFallbackCopy ? null : previousLabel,
      latestSignalLabel: useFallbackCopy ? null : latestLabel,
      possibleRepeat: possibleRepeat,
    );
  }

  bool _isGroundedThread(String? thread) {
    final trimmed = thread?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    if (trimmed == ConsumerUiCopy.secondSessionFallbackWhatRepeated) {
      return false;
    }
    if (!_isStrongUserThread(trimmed)) return false;
    return !ComparisonEnginePrompt.violatesBannedPhrase(trimmed);
  }

  bool _isStrongUserThread(String thread) {
    final stripped = thread.replaceAll('"', '').trim();
    if (stripped.isEmpty) return false;
    if (stripped.contains(',')) {
      final parts = stripped
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.length > 3 && !_threadStopwords.contains(part))
          .toList();
      return parts.length >= 2;
    }
    final words = stripped
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2 && !_threadStopwords.contains(word))
        .toList();
    return words.length >= 3;
  }

  bool _hasUserWordOverlap(String previousText, String latestText) {
    if (_longestSharedPhrase(previousText, latestText) != null) return true;
    return _sharedSignificantTokens(previousText, latestText).length >= 2;
  }

  String? _userThread({
    required JournalEntry previous,
    required JournalEntry latest,
    required InterpretationRead? groundedRead,
    required ArchiveEvidenceAnalysis analysis,
  }) {
    if (groundedRead != null && groundedRead.evidenceTags.isNotEmpty) {
      final tags = groundedRead.evidenceTags.take(3).join(', ');
      final sanitized = _sanitizeUserPhrase(tags);
      if (sanitized != null) return sanitized;
    }

    if (groundedRead != null) {
      final why = groundedRead.whyThisRead.trim();
      if (why.startsWith('You mentioned ')) {
        final mention = why
            .substring('You mentioned '.length)
            .replaceAll('.', '')
            .trim();
        final sanitized = _sanitizeUserPhrase(mention);
        if (sanitized != null) return sanitized;
      }
    }

    final previousText = _entryText(previous);
    final latestText = _entryText(latest);
    final sharedPhrase = _longestSharedPhrase(previousText, latestText);
    if (sharedPhrase != null) {
      final sanitized = _sanitizeUserPhrase('"$sharedPhrase"');
      if (sanitized != null) return sanitized;
    }

    final repeatedWord = _repeatedWordAcross(previousText, latestText);
    if (repeatedWord != null && !_threadStopwords.contains(repeatedWord)) {
      final sanitized = _sanitizeUserPhrase('"$repeatedWord"');
      if (sanitized != null) return sanitized;
    }

    final sharedTokens = _meaningfulSharedTokens(previousText, latestText);
    if (sharedTokens.isNotEmpty) {
      final sanitized = _sanitizeUserPhrase(sharedTokens.take(3).join(', '));
      if (sanitized != null) return sanitized;
    }

    if (analysis.repeatedPressurePhrases.isNotEmpty) {
      for (final phrase in analysis.repeatedPressurePhrases) {
        final sanitized = _sanitizeUserPhrase('"$phrase"');
        if (sanitized != null &&
            previousText.toLowerCase().contains(
              sanitized.replaceAll('"', '').toLowerCase(),
            )) {
          return sanitized;
        }
      }
    }

    return null;
  }

  String? _userChange({
    required JournalEntry previous,
    required JournalEntry latest,
    required ArchiveEvidenceAnalysis analysis,
    required String? thread,
  }) {
    final previousText = _entryText(previous);
    final latestText = _entryText(latest);

    final quotedChange = analysis.whatChangedLine;
    if (quotedChange != null && quotedChange.contains('"')) {
      final sanitized = _sanitizeUserPhrase(quotedChange);
      if (sanitized != null) return sanitized;
    }

    final latestSnippet = _distinctLatestSnippet(
      previousText: previousText,
      latestText: latestText,
      thread: thread,
    );
    if (latestSnippet != null) {
      final sanitized = _sanitizeUserPhrase(
        'The latest moment adds: "$latestSnippet".',
      );
      if (sanitized != null) return sanitized;
    }

    final sharedPhrase = _longestSharedPhrase(previousText, latestText);
    if (sharedPhrase != null &&
        latestText.toLowerCase() != previousText.toLowerCase()) {
      final sanitized = _sanitizeUserPhrase(
        'The latest moment still uses "$sharedPhrase".',
      );
      if (sanitized != null) return sanitized;
    }

    if (previousText.toLowerCase() != latestText.toLowerCase()) {
      return _defaultChangeFallback;
    }

    return _defaultChangeFallback;
  }

  String _entryText(JournalEntry entry) {
    return resolveEntryDisplayText(entry).text.trim();
  }

  List<String> _normalizeWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();
  }

  String? _longestSharedPhrase(String a, String b) {
    final aWords = _normalizeWords(a);
    final bWords = _normalizeWords(b);
    if (aWords.length < 3 || bWords.length < 3) return null;

    String? best;
    final maxLen = aWords.length < bWords.length
        ? aWords.length
        : bWords.length;
    for (var len = maxLen; len >= 3; len--) {
      for (var i = 0; i <= aWords.length - len; i++) {
        final slice = aWords.sublist(i, i + len);
        if (_containsWordSequence(bWords, slice)) {
          final phrase = slice.join(' ');
          if (best == null || phrase.length > best.length) {
            best = phrase;
          }
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  bool _containsWordSequence(List<String> haystack, List<String> needle) {
    if (needle.isEmpty || haystack.length < needle.length) return false;
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      var matches = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  String? _repeatedWordAcross(String a, String b) {
    final aWords = _normalizeWords(a);
    final bWords = _normalizeWords(b).toSet();
    final shared =
        aWords
            .where((word) => word.length > 4 && bWords.contains(word))
            .toList()
          ..sort((left, right) => right.length.compareTo(left.length));
    return shared.isEmpty ? null : shared.first;
  }

  List<String> _meaningfulSharedTokens(String a, String b) {
    return _sharedSignificantTokens(
      a,
      b,
    ).where((token) => !_threadStopwords.contains(token)).toList();
  }

  List<String> _sharedSignificantTokens(String a, String b) {
    final aTokens = _tokenSet(a);
    final bTokens = _tokenSet(b);
    return aTokens.intersection(bTokens).toList()
      ..sort((left, right) => right.length.compareTo(left.length));
  }

  String? _distinctLatestSnippet({
    required String previousText,
    required String latestText,
    required String? thread,
  }) {
    final latestWords = _normalizeWords(latestText);
    final previousWords = _normalizeWords(previousText).toSet();
    final novel = latestWords
        .where((word) => !previousWords.contains(word))
        .toList();
    if (novel.length < 3) return null;

    final start = latestWords.indexOf(novel.first);
    final end = start + 3 <= latestWords.length
        ? start + 3
        : latestWords.length;
    final snippet = latestWords.sublist(start, end).join(' ');
    if (thread != null && thread.toLowerCase().contains(snippet)) return null;
    return snippet;
  }

  String? _sanitizeUserPhrase(String? phrase) {
    if (phrase == null) return null;
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return null;
    if (ComparisonEnginePrompt.violatesBannedPhrase(trimmed)) return null;
    if (trimmed.toLowerCase().startsWith('you may ')) return null;
    if (trimmed.toLowerCase().startsWith('your archive ')) return null;
    if (trimmed.toLowerCase().startsWith('both moments may touch on')) {
      return null;
    }
    return trimmed;
  }

  String _labelFor(
    InterpretationResult readResult,
    FirstSessionPattern pattern,
  ) {
    if (readResult.reads.isNotEmpty) {
      return _shortLabel(readResult.reads.first.title);
    }
    return _shortLabel(pattern.title);
  }

  double _overlapScore(
    FirstSessionPattern a,
    FirstSessionPattern b,
    InterpretationResult previousRead,
    InterpretationResult latestRead,
  ) {
    if (a.categoryId == b.categoryId) return 1;
    if (previousRead.reads.isNotEmpty &&
        latestRead.reads.isNotEmpty &&
        previousRead.reads.first.id == latestRead.reads.first.id) {
      return 0.8;
    }
    final aTokens = _tokenSet(
      '${a.title} ${a.whyNoticed} ${a.chips.join(' ')}',
    );
    final bTokens = _tokenSet(
      '${b.title} ${b.whyNoticed} ${b.chips.join(' ')}',
    );
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    final shared = aTokens.intersection(bTokens).length;
    return shared / aTokens.union(bTokens).length;
  }

  Set<String> _tokenSet(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3)
        .toSet();
  }

  String _shortLabel(String title) {
    final trimmed = title.trim();
    if (trimmed.length <= 48) return trimmed;
    return '${trimmed.substring(0, 45)}…';
  }
}