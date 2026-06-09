import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import 'return_capture_model.dart';
import 'return_comparison_model.dart';
import 'tomorrow_commitment_model.dart';
import 'tomorrow_return_loop_models.dart';

/// Compares today's reflection with yesterday's watch-for commitment.
class ReturnComparisonEngine {
  const ReturnComparisonEngine();

  ReturnComparison build({
    required TomorrowCommitment commitment,
    required JournalEntry entry,
    TomorrowReturnLoop? loop,
    DateTime? now,
    String? comparisonHint,
  }) {
    final clock = now ?? DateTime.now();
    final yesterdayWatchFor = _yesterdayWatchLabel(commitment);
    final todaySummary = _todaySummary(entry, loop);
    final todayBlob = _entryTextBlob(entry).toLowerCase();
    final watchTerms = _watchTerms(commitment);

    final status = _resolveStatus(
      entry: entry,
      todayBlob: todayBlob,
      todaySummary: todaySummary,
      watchTerms: watchTerms,
      commitment: commitment,
      comparisonHint: comparisonHint,
    );

    final chips = _chipsForStatus(status, commitment, todayBlob);
    final headline = _headline(status, comparisonHint: comparisonHint);
    final body = _body(
      status: status,
      yesterdayWatchFor: yesterdayWatchFor,
      todaySummary: todaySummary,
      commitment: commitment,
      comparisonHint: comparisonHint,
    );

    return ReturnComparison(
      yesterdayWatchFor: yesterdayWatchFor,
      todayReflectionSummary: todaySummary,
      comparisonStatus: status,
      headline: headline,
      body: body,
      chips: chips,
      createdAt: clock,
    );
  }

  String _yesterdayWatchLabel(TomorrowCommitment commitment) {
    final chips = commitment.displayWatchChips;
    if (chips.isNotEmpty) return chips.join(', ');
    final prompt = commitment.promptText.trim();
    if (prompt.isNotEmpty) return prompt;
    return ConsumerUiCopy.tomorrowCommitmentDefaultPrompt;
  }

  String _todaySummary(JournalEntry entry, TomorrowReturnLoop? loop) {
    if (loop != null && loop.noticedToday.trim().isNotEmpty) {
      return _clip(loop.noticedToday, 160);
    }
    final obs = entry.reflection.concreteObservation.trim();
    if (obs.length >= 12) return _clip(obs, 160);
    final signal = entry.reflection.repeatedSignal.trim();
    if (signal.length >= 12) return _clip(signal, 160);
    final transcript = entry.transcript.trim();
    if (transcript.length >= 20) return _clip(transcript, 160);
    return ConsumerUiCopy.returnComparisonShortReflection;
  }

  String _entryTextBlob(JournalEntry entry) {
    return '${entry.transcript} ${entry.reflection.concreteObservation} '
        '${entry.reflection.repeatedSignal} '
        '${entry.reflection.exactLanguagePattern}';
  }

  List<String> _watchTerms(TomorrowCommitment commitment) {
    final terms = <String>[];
    for (final chip in commitment.displayWatchChips) {
      terms.addAll(_tokenize(chip).where(_isDistinctWatchTerm));
    }
    for (final t in _tokenize(commitment.promptText)) {
      if (_isDistinctWatchTerm(t)) terms.add(t);
    }
    return terms.toSet().toList();
  }

  bool _isDistinctWatchTerm(String term) {
    if (term.length < 5) return false;
    const stop = {
      'today',
      'notice',
      'whether',
      'things',
      'without',
      'asking',
      'help',
      'about',
      'your',
      'tomorrow',
      'again',
    };
    return !stop.contains(term);
  }

  ReturnComparisonStatus _resolveStatus({
    required JournalEntry entry,
    required String todayBlob,
    required String todaySummary,
    required List<String> watchTerms,
    required TomorrowCommitment commitment,
    String? comparisonHint,
  }) {
    final rawLen = _meaningfulTextLength(entry);
    if (rawLen < 36 && _isKnownHint(comparisonHint)) {
      return _statusFromComparisonHint(comparisonHint!);
    }
    if (rawLen < 36) {
      return ReturnComparisonStatus.unclear;
    }

    var overlap = _overlapCount(todayBlob, watchTerms);
    overlap += _chipPhraseOverlap(todayBlob, commitment.displayWatchChips);
    final easedHits = _countAny(todayBlob, _easedMarkers);
    final shiftHits = _countAny(todayBlob, _shiftMarkers);

    if (shiftHits >= 2 && overlap == 0) {
      return ReturnComparisonStatus.shifted;
    }

    if (overlap >= 2) {
      if (easedHits >= 1) return ReturnComparisonStatus.eased;
      return ReturnComparisonStatus.repeated;
    }
    if (overlap == 1) {
      if (shiftHits >= 1) return ReturnComparisonStatus.shifted;
      if (easedHits >= 1) return ReturnComparisonStatus.eased;
      return ReturnComparisonStatus.repeated;
    }

    if (shiftHits >= 1) return ReturnComparisonStatus.shifted;
    if (easedHits >= 1) return ReturnComparisonStatus.eased;

    if (_isKnownHint(comparisonHint)) {
      return _statusFromComparisonHint(comparisonHint!);
    }
    return ReturnComparisonStatus.absent;
  }

  bool _isKnownHint(String? hint) {
    if (hint == null || hint.isEmpty) return false;
    return hint == ReturnCaptureComparisonHints.same ||
        hint == ReturnCaptureComparisonHints.lighter ||
        hint == ReturnCaptureComparisonHints.heavier ||
        hint == ReturnCaptureComparisonHints.changed;
  }

  ReturnComparisonStatus _statusFromComparisonHint(String hint) {
    switch (hint) {
      case ReturnCaptureComparisonHints.same:
        return ReturnComparisonStatus.repeated;
      case ReturnCaptureComparisonHints.lighter:
        return ReturnComparisonStatus.eased;
      case ReturnCaptureComparisonHints.heavier:
        return ReturnComparisonStatus.repeated;
      case ReturnCaptureComparisonHints.changed:
        return ReturnComparisonStatus.shifted;
      default:
        return ReturnComparisonStatus.unclear;
    }
  }

  List<String> _chipsForStatus(
    ReturnComparisonStatus status,
    TomorrowCommitment commitment,
    String todayBlob,
  ) {
    switch (status) {
      case ReturnComparisonStatus.repeated:
        return [
          ConsumerUiCopy.returnComparisonChipShowedAgain,
          ...commitment.displayWatchChips.take(2),
        ].take(3).toList();
      case ReturnComparisonStatus.shifted:
        final shifted = [
          ConsumerUiCopy.returnComparisonChipChangedShape,
          if (_countAny(todayBlob, const ['person', 'someone', 'family']) > 0)
            'different person',
          if (_countAny(todayBlob, const ['worry', 'anxious', 'stress']) > 0)
            'more worry',
        ].where((c) => c.trim().isNotEmpty).take(3).toList();
        return shifted.isEmpty
            ? [ConsumerUiCopy.returnComparisonChipChangedShape]
            : shifted;
      case ReturnComparisonStatus.eased:
        return [
          ConsumerUiCopy.returnComparisonChipLighterToday,
          ...commitment.displayWatchChips.take(1),
        ].take(3).toList();
      case ReturnComparisonStatus.absent:
        return [
          ConsumerUiCopy.returnComparisonChipNotThereToday,
          ...commitment.displayWatchChips.take(1),
        ].take(3).toList();
      case ReturnComparisonStatus.unclear:
        return [ConsumerUiCopy.returnComparisonChipNeedAnotherMoment];
    }
  }

  String _headline(
    ReturnComparisonStatus status, {
    String? comparisonHint,
  }) {
    if (comparisonHint == ReturnCaptureComparisonHints.lighter) {
      return ConsumerUiCopy.returnComparisonHeadlineEased;
    }
    if (comparisonHint == ReturnCaptureComparisonHints.heavier) {
      return 'It felt heavier today.';
    }
    if (comparisonHint == ReturnCaptureComparisonHints.changed) {
      return ConsumerUiCopy.returnComparisonHeadlineShifted;
    }
    switch (status) {
      case ReturnComparisonStatus.repeated:
        return ConsumerUiCopy.returnComparisonHeadlineRepeated;
      case ReturnComparisonStatus.shifted:
        return ConsumerUiCopy.returnComparisonHeadlineShifted;
      case ReturnComparisonStatus.eased:
        return ConsumerUiCopy.returnComparisonHeadlineEased;
      case ReturnComparisonStatus.absent:
        return ConsumerUiCopy.returnComparisonHeadlineAbsent;
      case ReturnComparisonStatus.unclear:
        return ConsumerUiCopy.returnComparisonHeadlineUnclear;
    }
  }

  String _body({
    required ReturnComparisonStatus status,
    required String yesterdayWatchFor,
    required String todaySummary,
    required TomorrowCommitment commitment,
    String? comparisonHint,
  }) {
    final watch = yesterdayWatchFor;
    final today = _clip(todaySummary, 120);
    if (comparisonHint == ReturnCaptureComparisonHints.lighter) {
      return 'Yesterday you were watching for $watch. Today you marked it as lighter.';
    }
    if (comparisonHint == ReturnCaptureComparisonHints.heavier) {
      return 'Yesterday you were watching for $watch. Today you marked it as heavier.';
    }
    if (comparisonHint == ReturnCaptureComparisonHints.changed) {
      return 'Yesterday you were watching for $watch. Today something felt different.';
    }
    switch (status) {
      case ReturnComparisonStatus.repeated:
        return 'Yesterday you were watching for $watch. '
            "Today's reflection mentioned $today.";
      case ReturnComparisonStatus.shifted:
        final first = commitment.displayWatchChips.firstOrNull ?? watch;
        return 'Yesterday it was about $first. '
            "Today it showed up differently: $today.";
      case ReturnComparisonStatus.eased:
        return 'Yesterday this felt heavy around $watch. '
            "Today you mentioned similar pressure, but with more distance: $today.";
      case ReturnComparisonStatus.absent:
        return 'Yesterday you were watching for $watch. '
            "Today's reflection pointed somewhere else: $today.";
      case ReturnComparisonStatus.unclear:
        return ConsumerUiCopy.returnComparisonBodyUnclear;
    }
  }

  static const _easedMarkers = [
    'lighter',
    'calmer',
    'easier',
    'distance',
    'less heavy',
    'not as bad',
    'slowing down',
    'breathing room',
  ];

  static const _shiftMarkers = [
    'disappoint',
    'someone',
    'person',
    'family',
    'friend',
    'work',
    'evening',
    'morning',
    'worry',
    'anxious',
    'different',
    'instead',
  ];

  int _chipPhraseOverlap(String blob, List<String> chips) {
    var count = 0;
    for (final chip in chips) {
      final phrase = chip.trim().toLowerCase();
      if (phrase.length >= 8 && blob.contains(phrase)) count++;
    }
    return count;
  }

  int _overlapCount(String blob, List<String> terms) {
    var count = 0;
    for (final term in terms) {
      if (blob.contains(term)) count++;
    }
    return count;
  }

  int _countAny(String blob, List<String> markers) {
    var count = 0;
    for (final m in markers) {
      if (blob.contains(m)) count++;
    }
    return count;
  }

  List<String> _tokenize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toList();
  }

  int _meaningfulTextLength(JournalEntry entry) {
    final parts = [
      entry.transcript,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
      entry.reflection.exactLanguagePattern,
    ];
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).join(' ').length;
  }

  String _clip(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
