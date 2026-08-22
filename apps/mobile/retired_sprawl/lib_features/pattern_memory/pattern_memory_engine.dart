import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';

/// Turns repeated check-ins into a single evolving pattern memory.
///
/// Pure logic: no storage, no side effects. Extraction stays conservative so
/// the memory never overclaims what the person said.
class PatternMemoryEngine {
  const PatternMemoryEngine();

  static const int _momentCap = 5;

  static const List<String> _beforeTriggers = [
    'right before',
    'before',
    'after',
    'when',
  ];

  static const List<String> _helpedKeywords = [
    'paused',
    'asked',
    'rested',
    'said no',
    'waited',
  ];

  static const List<String> _harderKeywords = [
    'carried',
    'said yes',
    'drained',
    'alone',
    'overwhelmed',
  ];

  PatternMemory apply(
    PatternMemory? previous,
    PatternMemoryUpdate update, {
    required String patternTitle,
  }) {
    final hint = PatternMemoryResultHint.normalize(update.resultHint);
    final title = patternTitle.trim().isNotEmpty
        ? patternTitle.trim()
        : (previous?.patternTitle ?? '');

    final base =
        previous ??
        PatternMemory(
          id: 'pm_${update.createdAt.microsecondsSinceEpoch}',
          patternTitle: title,
          createdAt: update.createdAt,
          updatedAt: update.createdAt,
        );

    final checkInCount = base.checkInCount + 1;
    var showedAgainCount = base.showedAgainCount;
    var lighterCount = base.lighterCount;
    var heavierCount = base.heavierCount;
    var changedCount = base.changedCount;

    switch (hint) {
      case PatternMemoryResultHint.same:
        showedAgainCount += 1;
      case PatternMemoryResultHint.lighter:
        lighterCount += 1;
      case PatternMemoryResultHint.heavier:
        heavierCount += 1;
      case PatternMemoryResultHint.changed:
        changedCount += 1;
    }

    final beforeMoments = _merge(
      base.commonBeforeMoments,
      _extractBeforeMoments(update.reflectionText),
    );
    final helpedMoments = hint == PatternMemoryResultHint.lighter
        ? _merge(
            base.helpedMoments,
            _extractKeywordMoments(update.reflectionText, _helpedKeywords),
          )
        : base.helpedMoments;
    final harderMoments = hint == PatternMemoryResultHint.heavier
        ? _merge(
            base.harderMoments,
            _extractKeywordMoments(update.reflectionText, _harderKeywords),
          )
        : base.harderMoments;

    final status = _status(
      checkInCount: checkInCount,
      showedAgainCount: showedAgainCount,
      lighterCount: lighterCount,
      heavierCount: heavierCount,
      changedCount: changedCount,
    );

    return base.copyWith(
      patternTitle: title,
      updatedAt: update.createdAt,
      checkInCount: checkInCount,
      showedAgainCount: showedAgainCount,
      lighterCount: lighterCount,
      heavierCount: heavierCount,
      changedCount: changedCount,
      lastResult: hint,
      commonBeforeMoments: beforeMoments,
      helpedMoments: helpedMoments,
      harderMoments: harderMoments,
      nextBestQuestion: nextBestQuestionFor(status),
      status: status,
    );
  }

  PatternMemoryStatus _status({
    required int checkInCount,
    required int showedAgainCount,
    required int lighterCount,
    required int heavierCount,
    required int changedCount,
  }) {
    if (checkInCount < 2) return PatternMemoryStatus.forming;

    // active: showing up again is the clear, dominant result.
    if (showedAgainCount > lighterCount &&
        showedAgainCount > heavierCount &&
        showedAgainCount > changedCount) {
      return PatternMemoryStatus.active;
    }
    if (lighterCount >= 2 && lighterCount >= heavierCount) {
      return PatternMemoryStatus.easing;
    }
    if (heavierCount >= 2) {
      return PatternMemoryStatus.needsAttention;
    }

    final distinctResults = [
      showedAgainCount,
      lighterCount,
      heavierCount,
      changedCount,
    ].where((c) => c > 0).length;
    if (changedCount >= 2 || distinctResults >= 2) {
      return PatternMemoryStatus.changing;
    }

    return PatternMemoryStatus.active;
  }

  String nextBestQuestionFor(PatternMemoryStatus status) {
    switch (status) {
      case PatternMemoryStatus.active:
        return 'What happens right before it shows up?';
      case PatternMemoryStatus.easing:
        return 'What helped make it lighter?';
      case PatternMemoryStatus.needsAttention:
        return 'What made it heavier?';
      case PatternMemoryStatus.changing:
        return 'What was different today?';
      case PatternMemoryStatus.forming:
        return 'Did this pattern show up again?';
    }
  }

  List<String> _extractBeforeMoments(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return const [];
    final lower = clean.toLowerCase();
    final found = <String>[];
    for (final trigger in _beforeTriggers) {
      final pattern = RegExp('\\b${RegExp.escape(trigger)}\\b');
      for (final match in pattern.allMatches(lower)) {
        final snippet = _snippetAfter(clean, match.end, maxWords: 5);
        if (snippet.isNotEmpty) found.add(snippet);
      }
    }
    return found;
  }

  List<String> _extractKeywordMoments(String text, List<String> keywords) {
    final clean = text.trim();
    if (clean.isEmpty) return const [];
    final lower = clean.toLowerCase();
    final found = <String>[];
    for (final keyword in keywords) {
      final pattern = RegExp('\\b${RegExp.escape(keyword)}\\b');
      final match = pattern.firstMatch(lower);
      if (match == null) continue;
      final snippet = _snippetAround(clean, match.start, maxWords: 5);
      if (snippet.isNotEmpty) found.add(snippet);
    }
    return found;
  }

  /// Words after [start], stopping at sentence punctuation.
  String _snippetAfter(String source, int start, {required int maxWords}) {
    if (start >= source.length) return '';
    final rest = source.substring(start).trim();
    return _takeWords(rest, maxWords);
  }

  /// A short window starting at the keyword, stopping at punctuation.
  String _snippetAround(String source, int start, {required int maxWords}) {
    final rest = source.substring(start).trim();
    return _takeWords(rest, maxWords);
  }

  String _takeWords(String text, int maxWords) {
    var clause = text;
    final stop = RegExp(r'[.;,!?\n]');
    final stopMatch = stop.firstMatch(clause);
    if (stopMatch != null) {
      clause = clause.substring(0, stopMatch.start);
    }
    final words = clause
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final taken = words.take(maxWords).join(' ').trim().toLowerCase();
    return taken;
  }

  List<String> _merge(List<String> previous, List<String> next) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in [...next, ...previous]) {
      final key = item.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(item.trim());
      if (result.length >= _momentCap) break;
    }
    return result;
  }
}