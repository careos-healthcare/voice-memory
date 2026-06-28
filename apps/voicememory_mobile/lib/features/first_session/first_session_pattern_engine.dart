import '../../models/journal_entry.dart';
import '../timeline/timeline_entry_display.dart';
import 'first_session_pattern_category.dart';
import 'first_session_pattern_model.dart';
import '../archive_evidence/archive_pattern_copy_guard.dart';

/// Builds the first named pattern from a user's first saved reflection.
class FirstSessionPatternEngine {
  const FirstSessionPatternEngine();

  static const int _minStrongScore = 5;
  static const int _closeScoreGap = 3;
  static const double _overconfidentThreshold = 0.65;

  static const List<String> _negationTokens = [
    'not',
    'no',
    'never',
    'stopped',
    'finally',
    'less',
    'without',
    "didn't",
    'didnt',
    'did not',
    "don't",
    'dont',
  ];

  static const Map<FirstSessionPatternCategory, Set<String>>
  _primaryIntensityKeywords = {
    FirstSessionPatternCategory.responsibility: {
      'guilt',
      'guilty',
      'pressure',
      'responsibility',
      'responsible',
    },
    FirstSessionPatternCategory.worry: {
      'worry',
      'worried',
      'anxious',
      'anxiety',
      'fear',
      'scared',
      'stress',
      'stressed',
    },
    FirstSessionPatternCategory.selfDoubt: {
      'doubt',
      'prove',
      'proving',
      'judged',
      'failure',
      'failed',
    },
    FirstSessionPatternCategory.avoidance: {
      'avoid',
      'avoiding',
      'procrastinate',
      'overwhelmed',
    },
    FirstSessionPatternCategory.burnout: {
      'exhausted',
      'drained',
      'burnout',
      'heavy',
      'flat',
      'numb',
    },
  };

  static const List<String> _positiveTokens = [
    'calm',
    'good',
    'relieved',
    'proud',
    'enjoyed',
    'laughed',
    'peaceful',
    'okay',
    'ok',
    'better',
    'lighter',
    'grateful',
    'happy',
    'relaxed',
  ];

  static const List<String> _emotionalBoostTerms = [
    'guilt',
    'guilty',
    'anxious',
    'anxiety',
    'exhausted',
    'judged',
    'overwhelmed',
    'disappointed',
  ];

  static const Set<String> _weakLonelyKeywords = {
    'tired',
    'work',
    'friend',
    'message',
    'yes',
    'help',
    'ask',
    'tomorrow',
    'later',
    'sleep',
    'family',
    'partner',
    'boss',
  };

  static const Set<String> _relationshipTensionRequired = {
    'tension',
    'argument',
    'upset',
    'awkward',
    'ignored',
    'disappointed',
    'fight',
    'conflict',
  };

  FirstSessionPattern build(
    JournalEntry entry, {
    DateTime? now,
    int alternativeIndex = 0,
    Map<FirstSessionPatternCategory, double> preferredCategoryBoosts = const {},
  }) {
    final result = _score(
      entry,
      preferredCategoryBoosts: preferredCategoryBoosts,
    );
    if (alternativeIndex > 0 && result.ranked.length > 1) {
      final pick = result.ranked[alternativeIndex % result.ranked.length];
      return _assemble(
        entry: entry,
        now: now ?? DateTime.now(),
        pick: pick,
        ranked: result.ranked,
        scoreResult: result,
        forceEarly: true,
      );
    }
    return _assemble(
      entry: entry,
      now: now ?? DateTime.now(),
      pick: result.selected,
      ranked: result.ranked,
      scoreResult: result,
    );
  }

  List<FirstSessionPattern> allAlternatives(
    JournalEntry entry, {
    DateTime? now,
    Map<FirstSessionPatternCategory, double> preferredCategoryBoosts = const {},
  }) {
    final result = _score(
      entry,
      preferredCategoryBoosts: preferredCategoryBoosts,
    );
    final clock = now ?? DateTime.now();
    return result.ranked
        .map(
          (r) => _assemble(
            entry: entry,
            now: clock,
            pick: r,
            ranked: result.ranked,
            scoreResult: result,
            forceEarly: true,
          ),
        )
        .toList();
  }

  FirstSessionPatternAlternative fallbackAlternative() {
    final def = _definitions[FirstSessionPatternCategory.fallback]!;
    return FirstSessionPatternAlternative(
      title: def.title,
      whyNoticed: def.whyNoticed,
      watchForText: def.watchForText,
      chips: def.chips,
      confidenceScore: 0.2,
      categoryId: FirstSessionPatternCategory.fallback.id,
    );
  }

  _ScoreResult _score(
    JournalEntry entry, {
    Map<FirstSessionPatternCategory, double> preferredCategoryBoosts = const {},
  }) {
    final rawBlob = _entryBlob(entry);
    final blob = _normalizeText(rawBlob);
    var negativePenaltyApplied = false;
    final ranked = <_CategoryScore>[];

    for (final cat in _scoringCategories) {
      final scored = _scoreCategory(blob, cat);
      if (scored.negationHits > 0) negativePenaltyApplied = true;
      if (scored.score > 0) ranked.add(scored);
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    final boosted = _applyPreferredBoosts(ranked, preferredCategoryBoosts);
    ranked
      ..clear()
      ..addAll(boosted);

    final top = ranked.isEmpty
        ? _CategoryScore.empty(FirstSessionPatternCategory.fallback.id)
        : ranked.first;

    final second = ranked.length > 1 ? ranked[1] : null;
    final secondScore = second?.score ?? 0;
    final weakOnly = top.weakOnly && top.score < _minStrongScore;
    final lowConfidence = top.score < _minStrongScore || weakOnly;
    final closeScores =
        !lowConfidence &&
        second != null &&
        top.score > 0 &&
        ((top.score - secondScore) < _closeScoreGap ||
            (secondScore / top.score) > 0.55);

    final positiveLean = _positiveLean(blob);
    final strongNegative =
        top.score >= _minStrongScore &&
        top.categoryId != FirstSessionPatternCategory.fallback.id;

    _CategoryScore selected;
    if (positiveLean && !strongNegative) {
      selected = _CategoryScore.fromDef(
        FirstSessionPatternCategory.lighter.id,
        score: 2,
        matchedPhrases: _positiveHits(blob),
        weakOnly: true,
      );
    } else if (lowConfidence) {
      selected = _CategoryScore.empty(FirstSessionPatternCategory.fallback.id);
    } else {
      selected = top;
    }

    return _ScoreResult(
      selected: selected,
      ranked: ranked,
      closeScores: closeScores || lowConfidence,
      lowConfidence:
          lowConfidence ||
          selected.categoryId == FirstSessionPatternCategory.fallback.id,
      negativePenaltyApplied: negativePenaltyApplied,
      positiveLean: positiveLean,
      competingScores: _normalizedScores(ranked),
    );
  }

  _CategoryScore _scoreCategory(String blob, FirstSessionPatternCategory cat) {
    final def = _definitions[cat]!;
    var score = 0;
    var phraseHits = 0;
    var keywordHits = 0;
    var negationHits = 0;
    var weakOnlyPoints = 0;
    final hits = <String, int>{};

    for (final phrase in def.phrases) {
      final occurrences = _findTermOccurrences(blob, phrase);
      if (occurrences.isEmpty) continue;
      final occ = occurrences.firstWhere(
        (o) => !o.negated,
        orElse: () => occurrences.first,
      );
      if (occ.negated) {
        negationHits++;
        continue;
      }
      score += 4;
      phraseHits++;
      hits[phrase] = 1;
    }

    for (final word in def.keywords) {
      final occurrences = _findTermOccurrences(blob, word);
      if (occurrences.isEmpty) continue;
      final occ = occurrences.firstWhere(
        (o) => !o.negated,
        orElse: () => occurrences.first,
      );
      if (occ.negated) {
        negationHits++;
        continue;
      }
      final weight = _weakLonelyKeywords.contains(word) ? 1 : 2;
      score += weight;
      keywordHits++;
      if (_weakLonelyKeywords.contains(word)) weakOnlyPoints += weight;
      hits[word] = 1;
    }

    if (cat == FirstSessionPatternCategory.relationship) {
      final hasTension = _relationshipTensionRequired.any(
        (t) => _findTermOccurrences(blob, t).any((o) => !o.negated),
      );
      if (!hasTension) {
        if (phraseHits == 0 && keywordHits <= 2) {
          score = 0;
        } else {
          score = (score * 0.35).round();
        }
      }
    }

    if (cat == FirstSessionPatternCategory.burnout) {
      final hasStrong = [
        'exhausted',
        'drained',
        'burnout',
        'burnt out',
        'no energy',
      ].any((t) => _findTermOccurrences(blob, t).any((o) => !o.negated));
      if (!hasStrong && hits.containsKey('tired')) {
        score = (score * 0.3).round();
      }
    }

    for (final term in _emotionalBoostTerms) {
      if (!def.keywords.contains(term) &&
          !def.phrases.any((p) => p.contains(term))) {
        continue;
      }
      final occurrences = _findTermOccurrences(blob, term);
      for (final occ in occurrences) {
        if (occ.negated) continue;
        score += 2;
        hits[term] = (hits[term] ?? 0) + 1;
      }
    }

    final primary = _primaryIntensityKeywords[cat] ?? const {};
    final hasIntensity =
        phraseHits > 0 ||
        keywordHits >= 2 ||
        (keywordHits >= 1 && _hasEmotionalHit(hits)) ||
        hits.keys.any(primary.contains);
    if (!hasIntensity) {
      score = (score * 0.25).round();
    }

    final weakOnly = score > 0 && weakOnlyPoints >= score - phraseHits * 3;

    final matched = hits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _CategoryScore(
      categoryId: cat.id,
      score: score,
      matchedPhrases: matched.map((e) => e.key).take(4).toList(),
      weakOnly: weakOnly,
      negationHits: negationHits,
    );
  }

  FirstSessionPattern _assemble({
    required JournalEntry entry,
    required DateTime now,
    required _CategoryScore pick,
    required List<_CategoryScore> ranked,
    required _ScoreResult scoreResult,
    bool forceEarly = false,
  }) {
    final category = firstSessionPatternCategoryFromIdOrFallback(
      pick.categoryId,
    );
    final def =
        _definitions[category] ??
        _definitions[FirstSessionPatternCategory.fallback]!;
    final topScore = pick.score;
    final secondScore = ranked.length > 1 ? ranked[1].score : 0;
    final gap = topScore - secondScore;
    final ambiguityMargin = topScore == 0
        ? 0.0
        : (gap / topScore).clamp(0.0, 1.0).toDouble();

    var lowConfidence = scoreResult.lowConfidence;
    var closeScores = scoreResult.closeScores;
    var confidenceScore = _confidenceScore(
      score: topScore,
      gap: gap,
      lowConfidence: lowConfidence,
      closeScores: closeScores,
      weakOnly: pick.weakOnly,
    );

    if (closeScores) {
      confidenceScore = confidenceScore.clamp(0, 0.55);
    }
    if (pick.weakOnly || topScore < _minStrongScore) {
      confidenceScore = confidenceScore.clamp(0, 0.44);
      lowConfidence = true;
    }

    FirstSessionConfidenceLabel label;
    if (forceEarly || closeScores || lowConfidence) {
      label = FirstSessionConfidenceLabel.early;
    } else if (confidenceScore >= 0.72) {
      label = FirstSessionConfidenceLabel.strong;
    } else if (confidenceScore >= 0.45) {
      label = FirstSessionConfidenceLabel.forming;
    } else {
      label = FirstSessionConfidenceLabel.early;
    }

    final isAmbiguous =
        ranked.length > 1 &&
        (closeScores ||
            (topScore >= _minStrongScore &&
                secondScore >= _minStrongScore &&
                (secondScore / topScore.clamp(1, 999)) > 0.55));
    final alternatives = <FirstSessionPatternAlternative>[];
    void addAlternative(_CategoryScore other) {
      if (other.categoryId == pick.categoryId) return;
      final otherCat = firstSessionPatternCategoryFromIdOrFallback(
        other.categoryId,
      );
      final otherDef = _definitions[otherCat]!;
      alternatives.add(
        FirstSessionPatternAlternative(
          title: otherDef.title,
          whyNoticed: otherDef.whyNoticed,
          watchForText: otherDef.watchForText,
          chips: otherDef.chips,
          confidenceScore: _confidenceScore(
            score: other.score,
            gap: 0,
            lowConfidence: other.score < _minStrongScore,
            closeScores: true,
            weakOnly: other.weakOnly,
          ),
          categoryId: other.categoryId,
        ),
      );
    }

    if (isAmbiguous || lowConfidence) {
      for (final other
          in ranked.where((r) => r.categoryId != pick.categoryId).take(2)) {
        addAlternative(other);
      }
    }

    if (category != FirstSessionPatternCategory.fallback &&
        category != FirstSessionPatternCategory.lighter &&
        alternatives.length < 2) {
      addAlternative(
        _CategoryScore.fromDef(
          FirstSessionPatternCategory.fallback.id,
          score: 1,
          matchedPhrases: const [],
          weakOnly: true,
        ),
      );
    }

    final matchReason = _matchReason(
      category: category,
      matchedPhrases: pick.matchedPhrases,
      lowConfidence: lowConfidence,
      isAmbiguous: isAmbiguous,
    );

    return FirstSessionPattern(
      id: 'fs_${now.microsecondsSinceEpoch}',
      createdAt: now,
      title: def.title,
      whyNoticed: def.whyNoticed,
      watchForText: def.watchForText,
      chips: def.chips,
      confidenceLabel: label,
      sourceTextPreview: _preview(entry),
      matchReason: matchReason,
      confidenceScore: confidenceScore,
      matchedPhrases: pick.matchedPhrases.take(3).toList(),
      alternativePatterns: alternatives,
      userCanCorrect:
          isAmbiguous ||
          alternatives.isNotEmpty ||
          confidenceScore < 0.72 ||
          lowConfidence,
      categoryId: category.id,
      category: category,
      competingCategoryScores: scoreResult.competingScores,
      ambiguityMargin: ambiguityMargin,
      negativeMatchPenaltyApplied: scoreResult.negativePenaltyApplied,
      isAmbiguousMatch: isAmbiguous,
    );
  }

  String _matchReason({
    required FirstSessionPatternCategory category,
    required List<String> matchedPhrases,
    required bool lowConfidence,
    required bool isAmbiguous,
  }) {
    if (isAmbiguous) {
      return 'This could be a few things.';
    }
    if (category == FirstSessionPatternCategory.lighter) {
      return 'Something in this moment felt a bit lighter.';
    }
    if (lowConfidence || category == FirstSessionPatternCategory.fallback) {
      return 'This may be ordinary, but ordinary moments are where patterns start.';
    }
    if (matchedPhrases.isEmpty) {
      return _definitions[category]!.whyNoticed;
    }
    final sample = matchedPhrases.take(2).join(' and ');
    return 'Your words pointed toward $sample in this moment.';
  }

  double _confidenceScore({
    required int score,
    required int gap,
    required bool lowConfidence,
    required bool closeScores,
    required bool weakOnly,
  }) {
    if (lowConfidence || weakOnly) return 0.22;
    final base = (score / 20).clamp(0.0, 0.75);
    final gapBoost = closeScores ? 0 : (gap / 14).clamp(0.0, 0.12);
    return (base + gapBoost).clamp(0.0, _overconfidentThreshold);
  }

  Map<String, double> _normalizedScores(List<_CategoryScore> ranked) {
    if (ranked.isEmpty) return const {};
    final max = ranked.first.score.toDouble().clamp(1, 999);
    return {for (final r in ranked) r.categoryId: (r.score / max).clamp(0, 1)};
  }

  bool _positiveLean(String blob) {
    final pos = _positiveTokens
        .where((t) => _findTermOccurrences(blob, t).any((o) => !o.negated))
        .length;
    if (pos == 0) return false;
    final neg = _scoringCategories
        .map((c) => _scoreCategory(blob, c).score)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return pos >= 1 && neg < _minStrongScore;
  }

  List<String> _positiveHits(String blob) {
    return _positiveTokens
        .where((t) => _findTermOccurrences(blob, t).any((o) => !o.negated))
        .take(3)
        .toList();
  }

  bool _hasEmotionalHit(Map<String, int> hits) {
    return hits.keys.any(_emotionalBoostTerms.contains);
  }

  List<_CategoryScore> _applyPreferredBoosts(
    List<_CategoryScore> ranked,
    Map<FirstSessionPatternCategory, double> boosts,
  ) {
    if (boosts.isEmpty || ranked.isEmpty) {
      return List<_CategoryScore>.from(ranked);
    }

    final preTop = ranked.first;
    final preSecond = ranked.length > 1 ? ranked[1] : null;
    final decisiveLead =
        preSecond != null &&
        preTop.score >= _minStrongScore &&
        (preTop.score - preSecond.score) >= _closeScoreGap;

    if (decisiveLead) return List<_CategoryScore>.from(ranked);

    final adjusted = <_CategoryScore>[];
    for (final r in ranked) {
      final cat = firstSessionPatternCategoryFromIdOrFallback(r.categoryId);
      final boost = boosts[cat] ?? 0;
      if (boost <= 0 || r.score <= 0) {
        adjusted.add(r);
        continue;
      }
      var added = (r.score * boost).round();
      if (added < 1) added = 1;
      if (r.score < _minStrongScore) added = 1;
      adjusted.add(
        _CategoryScore(
          categoryId: r.categoryId,
          score: r.score + added,
          matchedPhrases: r.matchedPhrases,
          weakOnly: r.weakOnly,
          negationHits: r.negationHits,
        ),
      );
    }
    adjusted.sort((a, b) => b.score.compareTo(a.score));
    return List<_CategoryScore>.from(adjusted);
  }

  String _normalizeText(String raw) {
    var t = raw.toLowerCase();
    const replacements = {
      "couldn't": 'could not',
      'couldnt': 'could not',
      "can't": 'can not',
      'cant': 'can not',
      "didn't": 'did not',
      'didnt': 'did not',
      "don't": 'do not',
      'dont': 'do not',
      "won't": 'will not',
      'wont': 'will not',
      'burnt out': 'burnout',
    };
    for (final e in replacements.entries) {
      t = t.replaceAll(e.key, e.value);
    }
    return t;
  }

  List<_TermOccurrence> _findTermOccurrences(String blob, String term) {
    if (term.isEmpty) return const [];
    final out = <_TermOccurrence>[];
    var start = 0;
    while (true) {
      final i = blob.indexOf(term, start);
      if (i < 0) break;
      if (_isWholeTermMatch(blob, i, term.length)) {
        out.add(_TermOccurrence(index: i, negated: _isNegatedAt(blob, i)));
      }
      start = i + term.length;
    }
    return out;
  }

  bool _isWholeTermMatch(String blob, int index, int length) {
    final before = index > 0 ? blob[index - 1] : ' ';
    final afterIndex = index + length;
    final after = afterIndex < blob.length ? blob[afterIndex] : ' ';
    return !_isWordChar(before) && !_isWordChar(after);
  }

  bool _isWordChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
  }

  bool _isNegatedAt(String blob, int matchIndex) {
    final windowStart = (matchIndex - 32).clamp(0, blob.length);
    final before = blob.substring(windowStart, matchIndex).trim();
    if (before.isEmpty) return false;

    for (final token in _negationTokens) {
      if (token.contains(' ') && before.endsWith(token)) return true;
    }

    final words = before.split(RegExp(r'\s+'));
    if (words.isEmpty) return false;

    final last = words.last;
    final secondLast = words.length >= 2 ? words[words.length - 2] : null;
    if (secondLast != null) {
      final pair = '$secondLast $last';
      if (_negationTokens.contains(pair)) return true;
    }

    const immediateNegators = {
      'not',
      'no',
      'never',
      'without',
      'stopped',
      'finally',
      'less',
    };
    return immediateNegators.contains(last);
  }

  String _entryBlob(JournalEntry entry) {
    final display = resolveEntryDisplayText(entry);
    if (display.text.isNotEmpty &&
        !ArchivePatternCopyGuard.isBlockedPatternText(display.text)) {
      return display.text;
    }
    return '';
  }

  String _preview(JournalEntry entry) {
    final display = resolveEntryDisplayText(entry);
    final text = display.text.trim();
    if (text.isEmpty || ArchivePatternCopyGuard.isBlockedPatternText(text)) {
      return '';
    }
    return text.length > 96 ? '${text.substring(0, 93)}…' : text;
  }

  static const List<FirstSessionPatternCategory> _scoringCategories = [
    FirstSessionPatternCategory.responsibility,
    FirstSessionPatternCategory.worry,
    FirstSessionPatternCategory.relationship,
    FirstSessionPatternCategory.selfDoubt,
    FirstSessionPatternCategory.avoidance,
    FirstSessionPatternCategory.burnout,
  ];

  static final Map<FirstSessionPatternCategory, _PatternDefinition>
  _definitions = {
    FirstSessionPatternCategory.responsibility: _PatternDefinition(
      title: 'Taking responsibility before asking for help',
      whyNoticed:
          'You mentioned pressure, responsibility, or saying yes before checking what you need.',
      watchForText: 'whether you take responsibility before asking for help',
      chips: const ['saying yes fast', 'carrying it alone', 'asking late'],
      phrases: const [
        'saying yes',
        'have to',
        'let down',
        'needed me',
        'asking for help',
        'carrying',
      ],
      keywords: const [
        'responsibility',
        'responsible',
        'pressure',
        'guilt',
        'guilty',
        'help',
        'ask',
        'asked',
        'yes',
        'should',
        'disappoint',
        'alone',
        'everyone',
      ],
    ),
    FirstSessionPatternCategory.worry: _PatternDefinition(
      title: 'The same worry returning',
      whyNoticed:
          'You mentioned worry returning or taking up more space than you wanted.',
      watchForText: 'whether the same worry shows up again',
      chips: const ['same worry', 'overthinking', 'hard to switch off'],
      phrases: const [
        'cannot switch off',
        'can not switch off',
        'could not switch off',
        'same worry',
        'switch off',
        'thinking about it',
        'keeps coming back',
        'overthinking',
        'stopped overthinking',
      ],
      keywords: const [
        'worry',
        'worried',
        'anxious',
        'anxiety',
        'fear',
        'scared',
        'stress',
        'stressed',
        'replaying',
      ],
    ),
    FirstSessionPatternCategory.relationship: _PatternDefinition(
      title: 'Carrying tension with someone',
      whyNoticed:
          'You mentioned another person in a way that seemed to stay with you.',
      watchForText: 'whether this person or tension stays with you',
      chips: const ['same person', 'unsaid tension', 'replaying it'],
      phrases: const [],
      keywords: const [
        'family',
        'friend',
        'partner',
        'relationship',
        'mum',
        'mom',
        'dad',
        'parent',
        'boss',
        'colleague',
        'argument',
        'message',
        'reply',
        'ignored',
        'tension',
        'upset',
        'disappointed',
        'awkward',
      ],
    ),
    FirstSessionPatternCategory.selfDoubt: _PatternDefinition(
      title: 'Trying to prove you are enough',
      whyNoticed:
          'You mentioned doubting yourself or feeling behind compared with others.',
      watchForText: 'whether you feel you need to prove yourself again',
      chips: const ['not enough', 'proving myself', 'feeling judged'],
      phrases: const ['not good enough', 'doubt myself'],
      keywords: const [
        'prove',
        'proving',
        'failure',
        'failed',
        'judged',
        'behind',
        'compare',
        'comparison',
        'confidence',
        'doubt',
        'enough',
        'capable',
      ],
    ),
    FirstSessionPatternCategory.avoidance: _PatternDefinition(
      title: 'Putting off what matters',
      whyNoticed:
          'You mentioned avoiding, delaying, or finding it hard to start.',
      watchForText: 'whether you put off something that matters',
      chips: const ['putting it off', 'hard to start', 'stuck'],
      phrases: const [
        'put off',
        'hard to start',
        'cannot start',
        'can not start',
        'stuck on',
        'stuck with',
      ],
      keywords: const [
        'avoid',
        'avoiding',
        'procrastinate',
        'delayed',
        'overwhelmed',
        'freeze',
        'later',
      ],
    ),
    FirstSessionPatternCategory.burnout: _PatternDefinition(
      title: 'Running on empty',
      whyNoticed:
          'You mentioned feeling tired, drained, or too flat to keep going.',
      watchForText: 'whether tiredness changes what you say yes to',
      chips: const ['no energy', 'too much', 'feeling heavy'],
      phrases: const ['burnt out', 'no energy'],
      keywords: const [
        'tired',
        'exhausted',
        'drained',
        'burnout',
        'sleep',
        'heavy',
        'flat',
        'numb',
      ],
    ),
    FirstSessionPatternCategory.fallback: _PatternDefinition(
      title: 'Something worth watching',
      whyNoticed:
          'This may be ordinary, but ordinary moments are where patterns start.',
      watchForText: 'whether this same feeling shows up again',
      chips: const ['same feeling', 'same situation', 'same time of day'],
      phrases: const [],
      keywords: const [],
    ),
    FirstSessionPatternCategory.lighter: _PatternDefinition(
      title: 'Something felt lighter today',
      whyNoticed: 'Something in this moment felt a bit lighter.',
      watchForText: 'whether this lighter feeling shows up again',
      chips: const ['felt lighter', 'calmer moment', 'easier today'],
      phrases: const [],
      keywords: const [],
    ),
  };
}

class _PatternDefinition {
  const _PatternDefinition({
    required this.title,
    required this.whyNoticed,
    required this.watchForText,
    required this.chips,
    required this.phrases,
    required this.keywords,
  });

  final String title;
  final String whyNoticed;
  final String watchForText;
  final List<String> chips;
  final List<String> phrases;
  final List<String> keywords;
}

class _CategoryScore {
  const _CategoryScore({
    required this.categoryId,
    required this.score,
    required this.matchedPhrases,
    required this.weakOnly,
    required this.negationHits,
  });

  final String categoryId;
  final int score;
  final List<String> matchedPhrases;
  final bool weakOnly;
  final int negationHits;

  static _CategoryScore empty(String categoryId) => _CategoryScore(
    categoryId: categoryId,
    score: 0,
    matchedPhrases: const [],
    weakOnly: true,
    negationHits: 0,
  );

  static _CategoryScore fromDef(
    String categoryId, {
    required int score,
    required List<String> matchedPhrases,
    required bool weakOnly,
  }) => _CategoryScore(
    categoryId: categoryId,
    score: score,
    matchedPhrases: matchedPhrases,
    weakOnly: weakOnly,
    negationHits: 0,
  );
}

class _TermOccurrence {
  const _TermOccurrence({required this.index, required this.negated});

  final int index;
  final bool negated;
}

class _ScoreResult {
  const _ScoreResult({
    required this.selected,
    required this.ranked,
    required this.closeScores,
    required this.lowConfidence,
    required this.negativePenaltyApplied,
    required this.positiveLean,
    required this.competingScores,
  });

  final _CategoryScore selected;
  final List<_CategoryScore> ranked;
  final bool closeScores;
  final bool lowConfidence;
  final bool negativePenaltyApplied;
  final bool positiveLean;
  final Map<String, double> competingScores;
}
