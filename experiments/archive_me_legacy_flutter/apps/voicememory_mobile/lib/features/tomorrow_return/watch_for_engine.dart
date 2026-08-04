import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import 'return_capture_model.dart';
import 'tomorrow_return_loop_models.dart';
import 'watch_for_model.dart';

/// Suggested or evaluated watch-for prompts.
class WatchForEngine {
  const WatchForEngine();

  static const int _vagueReflectionLength = 36;

  static const List<({String text, List<String> chips})> fallbackAlternatives =
      [
        (
          text: 'whether you take responsibility before asking for help',
          chips: ['feeling responsible', 'doing it alone', 'asking for help'],
        ),
        (
          text: 'whether the same worry shows up again',
          chips: ['same worry', 'same pressure', 'tonight again'],
        ),
        (
          text: 'whether you say yes faster than you want to',
          chips: ['saying yes too fast', 'saying yes', 'too fast'],
        ),
      ];

  WatchForItem buildSuggested({
    required DateTime now,
    TomorrowReturnLoop? loop,
    List<String> signals = const [],
    JournalEntry? latestEntry,
    int alternativeIndex = 0,
  }) {
    final built = _primarySuggestion(
      loop: loop,
      signals: signals,
      entry: latestEntry,
    );
    final alt =
        fallbackAlternatives[alternativeIndex % fallbackAlternatives.length];
    final text = built?.text ?? alt.text;
    final chips = (built?.chips.isNotEmpty == true ? built!.chips : alt.chips)
        .take(3)
        .toList();

    return WatchForItem(
      id: 'wf_${now.microsecondsSinceEpoch}',
      createdAt: now,
      targetDate: WatchForItem.dateOnly(now).add(const Duration(days: 1)),
      sourceReflectionId: latestEntry?.id,
      text: text,
      chips: chips,
      status: WatchForStatus.pending,
      result: WatchForResult.none,
    );
  }

  ({String text, List<String> chips})? _primarySuggestion({
    TomorrowReturnLoop? loop,
    List<String> signals = const [],
    JournalEntry? entry,
  }) {
    if (loop != null && loop.watchForNextTime.trim().isNotEmpty) {
      return (
        text: loop.watchForNextTime.trim(),
        chips: loop.displayWatchChips,
      );
    }
    if (loop != null && loop.displayWatchChips.isNotEmpty) {
      final chip = loop.displayWatchChips.first;
      return (
        text: 'whether $chip shows up again in your next moment',
        chips: loop.displayWatchChips,
      );
    }
    if (signals.isNotEmpty) {
      final s = signals.first;
      return (
        text: 'whether $s shows up again tomorrow',
        chips: signals.take(3).toList(),
      );
    }
    if (entry != null) {
      final obs = entry.reflection.concreteObservation.trim();
      if (obs.length >= 16) {
        final clip = obs.length > 72 ? '${obs.substring(0, 69)}…' : obs;
        return (
          text: 'whether $clip comes up again',
          chips: entry.reflection.recurringThemes.take(3).toList(),
        );
      }
    }
    return null;
  }

  WatchForResult compareReflection({
    required WatchForItem pending,
    required JournalEntry entry,
    String? comparisonHint,
  }) {
    final rawLen = _meaningfulLength(entry);
    final fromTranscript = _compareFromTranscript(
      pending: pending,
      entry: entry,
      rawLen: rawLen,
    );

    if (rawLen < _vagueReflectionLength && _isKnownHint(comparisonHint)) {
      return _resultFromComparisonHint(comparisonHint!);
    }
    if (fromTranscript != WatchForResult.unclear) {
      return fromTranscript;
    }
    if (_isKnownHint(comparisonHint)) {
      return _resultFromComparisonHint(comparisonHint!);
    }
    return WatchForResult.unclear;
  }

  WatchForResult _compareFromTranscript({
    required WatchForItem pending,
    required JournalEntry entry,
    required int rawLen,
  }) {
    if (rawLen < _vagueReflectionLength) return WatchForResult.unclear;

    final blob = _entryBlob(entry).toLowerCase();
    var overlap = _overlapCount(blob, pending);
    overlap += _chipPhraseOverlap(blob, pending.chips);

    final shiftHits = _countAny(blob, _shiftMarkers);

    if (overlap >= 2) {
      return shiftHits >= 1
          ? WatchForResult.changedShape
          : WatchForResult.showedAgain;
    }
    if (overlap == 1) {
      return shiftHits >= 1
          ? WatchForResult.changedShape
          : WatchForResult.showedAgain;
    }
    if (shiftHits >= 2) return WatchForResult.changedShape;
    if (rawLen >= 48) return WatchForResult.didNotShow;
    return WatchForResult.unclear;
  }

  bool _isKnownHint(String? hint) {
    if (hint == null || hint.isEmpty) return false;
    return hint == ReturnCaptureComparisonHints.same ||
        hint == ReturnCaptureComparisonHints.lighter ||
        hint == ReturnCaptureComparisonHints.heavier ||
        hint == ReturnCaptureComparisonHints.changed;
  }

  WatchForResult _resultFromComparisonHint(String hint) {
    switch (hint) {
      case ReturnCaptureComparisonHints.same:
        return WatchForResult.showedAgain;
      case ReturnCaptureComparisonHints.lighter:
        return WatchForResult.changedShape;
      case ReturnCaptureComparisonHints.heavier:
        return WatchForResult.showedAgain;
      case ReturnCaptureComparisonHints.changed:
        return WatchForResult.changedShape;
      default:
        return WatchForResult.unclear;
    }
  }

  String resultHeadline(WatchForResult result, {String? comparisonHint}) {
    final hintHeadline = _headlineForComparisonHint(comparisonHint);
    if (hintHeadline != null) return hintHeadline;

    switch (result) {
      case WatchForResult.showedAgain:
        return ConsumerUiCopy.watchForResultShowedAgain;
      case WatchForResult.didNotShow:
        return ConsumerUiCopy.watchForResultDidNotShow;
      case WatchForResult.changedShape:
        return ConsumerUiCopy.watchForResultChangedShape;
      case WatchForResult.unclear:
        return ConsumerUiCopy.watchForResultUnclear;
      case WatchForResult.none:
        return '';
    }
  }

  String? _headlineForComparisonHint(String? hint) {
    if (!_isKnownHint(hint)) return null;
    switch (hint) {
      case ReturnCaptureComparisonHints.same:
        return ConsumerUiCopy.watchForResultShowedAgain;
      case ReturnCaptureComparisonHints.lighter:
        return ConsumerUiCopy.watchForResultFeltLighterToday;
      case ReturnCaptureComparisonHints.heavier:
        return ConsumerUiCopy.watchForResultFeltHeavierToday;
      case ReturnCaptureComparisonHints.changed:
        return ConsumerUiCopy.watchForResultSomethingChangedToday;
      default:
        return null;
    }
  }

  String resultBody({
    required WatchForItem pending,
    required WatchForResult result,
    required JournalEntry entry,
    String? comparisonHint,
  }) {
    final watch = _displayWatchText(pending);
    final hintBody = _bodyForComparisonHint(hint: comparisonHint, watch: watch);
    if (hintBody != null) return hintBody;

    switch (result) {
      case WatchForResult.showedAgain:
        return 'Yesterday you were watching for $watch. Today it showed up again.';
      case WatchForResult.didNotShow:
        return 'Yesterday you were watching for $watch. It did not show up in today\'s moment.';
      case WatchForResult.changedShape:
        return 'Yesterday you were watching for $watch. Today it changed shape in what you said.';
      case WatchForResult.unclear:
        return ConsumerUiCopy.watchForResultBodyUnclear;
      case WatchForResult.none:
        return '';
    }
  }

  String? _bodyForComparisonHint({
    required String? hint,
    required String watch,
  }) {
    if (!_isKnownHint(hint)) return null;
    switch (hint) {
      case ReturnCaptureComparisonHints.same:
        return 'Yesterday you were watching for $watch. Today it showed up again.';
      case ReturnCaptureComparisonHints.lighter:
        return 'Yesterday you were watching for $watch. Today you marked it as lighter.';
      case ReturnCaptureComparisonHints.heavier:
        return 'Yesterday you were watching for $watch. Today you marked it as heavier.';
      case ReturnCaptureComparisonHints.changed:
        return 'Yesterday you were watching for $watch. Today something felt different.';
      default:
        return null;
    }
  }

  String _displayWatchText(WatchForItem item) {
    final specific = item.displaySpecificPrompt.trim();
    if (specific.isNotEmpty) {
      return specific.startsWith('Tomorrow, notice ')
          ? specific.substring('Tomorrow, notice '.length)
          : specific;
    }
    final t = item.text.trim();
    if (t.startsWith('whether ')) return t.substring(8);
    return t;
  }

  String _entryBlob(JournalEntry entry) {
    return '${entry.transcript} ${entry.reflection.concreteObservation} '
        '${entry.reflection.repeatedSignal} ${entry.reflection.exactLanguagePattern}';
  }

  int _meaningfulLength(JournalEntry entry) {
    final parts = [
      entry.transcript,
      entry.reflection.concreteObservation,
      entry.reflection.repeatedSignal,
    ];
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ')
        .length;
  }

  int _overlapCount(String blob, WatchForItem pending) {
    final terms = <String>[
      ..._tokenize(pending.text),
      ...pending.chips.expand(_tokenize),
    ].where((t) => t.length >= 5).toSet();
    var count = 0;
    for (final term in terms) {
      if (blob.contains(term)) count++;
    }
    return count;
  }

  int _chipPhraseOverlap(String blob, List<String> chips) {
    var count = 0;
    for (final chip in chips) {
      final phrase = chip.trim().toLowerCase();
      if (phrase.length >= 8 && blob.contains(phrase)) count++;
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

  static const _shiftMarkers = [
    'disappoint',
    'someone',
    'person',
    'worry',
    'anxious',
    'different',
    'instead',
    'family',
  ];

  int _countAny(String blob, List<String> markers) {
    var count = 0;
    for (final m in markers) {
      if (blob.contains(m)) count++;
    }
    return count;
  }
}
