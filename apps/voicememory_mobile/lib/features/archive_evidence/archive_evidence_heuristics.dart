import '../../models/journal_entry.dart';
import '../timeline/timeline_entry_display.dart';
import 'archive_evidence_guard.dart';
import 'archive_intelligence_tier.dart';
import 'archive_pattern_copy_guard.dart';

/// Humble confidence band for Pro surfaces — never diagnostic.
enum ArchiveConfidenceBand { earlySignal, returningThread, strongerEvidence }

/// Strongest “oh wow” moment type when evidence supports it.
enum ArchiveOhWowKind { returned, changed, faded, currentBelief }

/// Local heuristic read of repeated evidence — no network AI.
class ArchiveEvidenceAnalysis {
  const ArchiveEvidenceAnalysis({
    required this.windowEntries,
    required this.totalEligibleCount,
    required this.possibleRepeat,
    required this.beliefLine,
    this.previousBeliefLine,
    this.evidenceLine,
    this.worthWatchingLine,
    this.whatChangedLine,
    this.whatToTestLine,
    this.whatReturnedLine,
    this.whatFadedLine,
    this.confidenceBand,
    this.evidenceSnippets = const [],
    this.repeatedPressurePhrases = const [],
    this.ohWowKind,
    this.ohWowTitle,
    this.ohWowBody,
  });

  final List<JournalEntry> windowEntries;
  final int totalEligibleCount;
  final bool possibleRepeat;
  final String beliefLine;
  final String? previousBeliefLine;
  final String? evidenceLine;
  final String? worthWatchingLine;
  final String? whatChangedLine;
  final String? whatToTestLine;
  final String? whatReturnedLine;
  final String? whatFadedLine;
  final ArchiveConfidenceBand? confidenceBand;
  final List<String> evidenceSnippets;
  final List<String> repeatedPressurePhrases;
  final ArchiveOhWowKind? ohWowKind;
  final String? ohWowTitle;
  final String? ohWowBody;

  static const empty = ArchiveEvidenceAnalysis(
    windowEntries: [],
    totalEligibleCount: 0,
    possibleRepeat: false,
    beliefLine: '',
  );
}

/// Deterministic phrase/context heuristics for archive belief surfaces.
class ArchiveEvidenceHeuristics {
  const ArchiveEvidenceHeuristics();

  static const Map<String, String> _pressurePhrases = {
    'behind': 'avoid feeling behind',
    'falling behind': 'avoid feeling behind',
    'feel behind': 'avoid feeling behind',
    'enough': 'push to feel enough',
    'not enough': 'push to feel enough',
    'guilty': 'carry guilt when resting',
    'prove': 'prove yourself through doing more',
    'should': 'feel pulled by a heavy should',
    'too late': 'worry about being too late',
    'say yes': 'say yes before checking capacity',
    'said yes': 'say yes before checking capacity',
    'agreed': 'agree before checking capacity',
    'capacity': 'ignore capacity limits',
    'tired': 'keep going when tired',
    'exhausted': 'keep going when exhausted',
    'avoid': 'avoid what feels uncomfortable',
    'failure': 'fear of failure',
    'letting people down': 'avoid letting people down',
    'letting down': 'avoid letting people down',
    'responsibility': 'take responsibility before asking for help',
  };

  static const Map<String, List<String>> _contextKeywords = {
    'work': [
      'work',
      'office',
      'deadline',
      'boss',
      'project',
      'job',
      'colleague',
    ],
    'family': ['family', 'kids', 'child', 'partner', 'parent', 'home'],
    'rest': ['rest', 'tired', 'sleep', 'exhausted', 'burned out', 'burnout'],
    'saying yes': ['yes', 'agree', 'help', 'capacity', 'commit'],
    'deadlines': ['deadline', 'due', 'late', 'overdue'],
    'money': ['money', 'bills', 'rent', 'pay', 'afford'],
    'health': ['health', 'sick', 'doctor', 'pain'],
    'relationships': ['friend', 'relationship', 'people', 'partner'],
  };

  static const List<String> _awarenessWords = [
    'noticed',
    'caught',
    'realized',
    'realised',
    'earlier',
    'sooner',
    'before i usually',
  ];

  static const List<String> _avoidanceWords = [
    'avoid',
    'avoided',
    'did not',
    "didn't",
    'skipped',
    'put off',
    'postponed',
  ];

  ArchiveEvidenceAnalysis analyze(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return ArchiveEvidenceAnalysis.empty;

    final windowSize = tier == ArchiveIntelligenceTier.proMax ? 8 : 3;
    final window = eligible.length > windowSize
        ? eligible.sublist(eligible.length - windowSize)
        : eligible;

    final texts = window
        .map((e) => resolveEntryDisplayText(e).text.trim().toLowerCase())
        .where(
          (t) =>
              t.length >= ArchiveEvidenceGuard.minimumTranscriptChars &&
              !ArchivePatternCopyGuard.isBlockedPatternText(t),
        )
        .toList();
    if (texts.length < 2) return ArchiveEvidenceAnalysis.empty;

    final allText = texts.join(' ');

    final pressureHits = _pressurePhrases.entries
        .where((e) => allText.contains(e.key))
        .map((e) => e.value)
        .toSet()
        .toList();

    final dominantPressure = pressureHits.isNotEmpty
        ? pressureHits.first
        : _fallbackPressure(window);

    final previousContext = _detectContext(texts.first);
    final latestContext = _detectContext(texts.last);
    final contextShifted =
        previousContext != null &&
        latestContext != null &&
        previousContext != latestContext;

    final phraseOverlap = _repeatedPhraseAcross(texts);
    final possibleRepeat =
        pressureHits.isNotEmpty ||
        phraseOverlap != null ||
        _sharedTokenOverlap(texts.first, texts.last) >= 0.35;

    final earlierAwareness = _awarenessWords.any(texts.last.contains);
    final repeatedAvoidance =
        _avoidanceWords.any(texts.last.contains) &&
        _avoidanceWords.any(
          (w) => texts.length >= 2 && texts[texts.length - 2].contains(w),
        );

    final beliefLine = _beliefLine(
      dominantPressure,
      pressureHits,
      possibleRepeat,
    );
    final previousBeliefLine =
        tier == ArchiveIntelligenceTier.proMax &&
            eligible.length >= 3 &&
            previousContext != latestContext
        ? 'Your archive used to point toward $previousContext.'
        : null;

    final whatChanged = _whatChangedLine(
      previousContext: previousContext,
      latestContext: latestContext,
      contextShifted: contextShifted,
      earlierAwareness: earlierAwareness,
      repeatedAvoidance: repeatedAvoidance,
      dominantPressure: dominantPressure,
      phraseOverlap: phraseOverlap,
    );

    final whatFaded = _whatFadedLine(
      olderText: texts.length >= 2 ? texts[texts.length - 2] : texts.first,
      latestText: texts.last,
      previousContext: previousContext,
    );

    final whatReturned = possibleRepeat
        ? (dominantPressure != null
              ? 'The repeated thread may be $dominantPressure.'
              : 'Similar pressure may be returning across your recent moments.')
        : null;

    final confidenceBand = _confidenceBand(
      count: window.length,
      total: eligible.length,
      possibleRepeat: possibleRepeat,
      pressureHits: pressureHits.length,
    );

    final evidenceLine = tier == ArchiveIntelligenceTier.proMax
        ? '${eligible.length} ${eligible.length == 1 ? 'entry' : 'entries'} across your archive point toward this.'
        : '${window.length} ${window.length == 1 ? 'entry points' : 'entries point'} toward this.';

    final snippets = tier == ArchiveIntelligenceTier.proMax
        ? _evidenceSnippets(window)
        : const <String>[];

    final ohWow = _pickOhWow(
      possibleRepeat: possibleRepeat,
      whatChanged: whatChanged,
      whatFaded: whatFaded,
      beliefLine: beliefLine,
      dominantPressure: dominantPressure,
      earlierAwareness: earlierAwareness,
      contextShifted: contextShifted,
      previousContext: previousContext,
      latestContext: latestContext,
    );

    return ArchiveEvidenceAnalysis(
      windowEntries: window,
      totalEligibleCount: eligible.length,
      possibleRepeat: possibleRepeat,
      beliefLine: beliefLine,
      previousBeliefLine: previousBeliefLine,
      evidenceLine: evidenceLine,
      worthWatchingLine: 'This may be worth watching.',
      whatChangedLine: whatChanged,
      whatToTestLine: _whatToTestLine(dominantPressure, pressureHits),
      whatReturnedLine: whatReturned,
      whatFadedLine: whatFaded,
      confidenceBand: tier == ArchiveIntelligenceTier.proMax
          ? confidenceBand
          : null,
      evidenceSnippets: snippets,
      repeatedPressurePhrases: pressureHits,
      ohWowKind: ohWow?.kind,
      ohWowTitle: ohWow?.title,
      ohWowBody: ohWow?.body,
    );
  }

  String _beliefLine(
    String? dominantPressure,
    List<String> pressureHits,
    bool possibleRepeat,
  ) {
    if (dominantPressure != null && dominantPressure.contains('say yes')) {
      return 'The pressure may return around saying yes before checking capacity.';
    }
    if (dominantPressure != null) {
      return 'You may do more when you $dominantPressure.';
    }
    if (pressureHits.isNotEmpty) {
      return 'You may be ${pressureHits.first}.';
    }
    if (possibleRepeat) {
      return 'You may be doing more to avoid feeling behind.';
    }
    return 'Something similar may be showing up across your recent moments.';
  }

  String? _whatChangedLine({
    required String? previousContext,
    required String? latestContext,
    required bool contextShifted,
    required bool earlierAwareness,
    required bool repeatedAvoidance,
    required String? dominantPressure,
    required String? phraseOverlap,
  }) {
    if (contextShifted && previousContext != null && latestContext != null) {
      return 'Last time it was about $previousContext. This time it showed up around $latestContext.';
    }
    if (earlierAwareness) {
      return 'The same pressure returned, but you noticed it earlier this time.';
    }
    if (repeatedAvoidance) {
      return 'The same pressure returned, with repeated avoidance showing up again.';
    }
    if (dominantPressure != null && dominantPressure.contains('say yes')) {
      return 'This time, it showed up around saying yes too quickly.';
    }
    if (phraseOverlap != null) {
      return 'Your latest moment may echo “$phraseOverlap”.';
    }
    return 'Your latest moment may sit differently from the one before it.';
  }

  String? _whatFadedLine({
    required String olderText,
    required String latestText,
    required String? previousContext,
  }) {
    if (previousContext == null) return null;
    final keywords = _contextKeywords[previousContext];
    if (keywords == null) return null;
    final wasPresent = keywords.any(olderText.contains);
    final stillPresent = keywords.any(latestText.contains);
    if (wasPresent && !stillPresent) {
      return 'This has not shown up in the latest entry.';
    }
    return null;
  }

  String _whatToTestLine(String? dominantPressure, List<String> pressureHits) {
    if (dominantPressure != null && dominantPressure.contains('capacity')) {
      return 'Before agreeing, check whether you actually have capacity.';
    }
    if (pressureHits.any((p) => p.contains('say yes'))) {
      return 'Pause before agreeing to new requests.';
    }
    if (dominantPressure != null) {
      return 'Record another ordinary moment and notice whether you $dominantPressure again.';
    }
    return 'Record another ordinary moment and notice what feels different.';
  }

  ArchiveConfidenceBand? _confidenceBand({
    required int count,
    required int total,
    required bool possibleRepeat,
    required int pressureHits,
  }) {
    if (!possibleRepeat) return null;
    if (total >= 5 && pressureHits >= 2) {
      return ArchiveConfidenceBand.strongerEvidence;
    }
    if (count >= 3 || total >= 3) {
      return ArchiveConfidenceBand.returningThread;
    }
    return ArchiveConfidenceBand.earlySignal;
  }

  List<String> _evidenceSnippets(List<JournalEntry> window) {
    final snippets = <String>[];
    for (final entry in window.reversed) {
      final t = resolveEntryDisplayText(entry).text.trim();
      if (t.length < 20) continue;
      if (ArchivePatternCopyGuard.isBlockedPatternText(t)) continue;
      final snippet = t.length <= 96 ? t : '${t.substring(0, 93)}…';
      snippets.add(snippet);
      if (snippets.length >= 3) break;
    }
    return snippets;
  }

  String? _detectContext(String text) {
    for (final entry in _contextKeywords.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    return null;
  }

  String? _repeatedPhraseAcross(List<String> texts) {
    if (texts.length < 2) return null;
    final words = texts
        .expand((t) => t.split(RegExp(r'\s+')))
        .where((w) => w.length > 4)
        .toList();
    final counts = <String, int>{};
    for (final w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
    final repeated =
        counts.entries
            .where((e) => e.value >= 2)
            .map((e) => e.key)
            .where(
              (word) => !ArchivePatternCopyGuard.isBlockedPatternText(word),
            )
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    if (repeated.isEmpty) return null;
    final phrase = repeated.first;
    if (ArchivePatternCopyGuard.isBlockedPatternText(phrase)) return null;
    return phrase;
  }

  double _sharedTokenOverlap(String a, String b) {
    final aTokens = a
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    final bTokens = b
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    return aTokens.intersection(bTokens).length / aTokens.union(bTokens).length;
  }

  String? _fallbackPressure(List<JournalEntry> window) {
    for (final entry in window.reversed) {
      final lower = resolveEntryDisplayText(entry).text.toLowerCase();
      if (ArchivePatternCopyGuard.isBlockedPatternText(lower)) continue;
      for (final key in _pressurePhrases.keys) {
        if (lower.contains(key)) return _pressurePhrases[key];
      }
    }
    return null;
  }

  _OhWowCandidate? _pickOhWow({
    required bool possibleRepeat,
    required String? whatChanged,
    required String? whatFaded,
    required String beliefLine,
    required String? dominantPressure,
    required bool earlierAwareness,
    required bool contextShifted,
    required String? previousContext,
    required String? latestContext,
  }) {
    if (earlierAwareness && possibleRepeat) {
      return _OhWowCandidate(
        kind: ArchiveOhWowKind.changed,
        title: 'Something changed.',
        body:
            whatChanged ??
            'The same pressure returned, but you noticed it earlier this time.',
        score: 90,
      );
    }
    if (contextShifted &&
        previousContext != null &&
        latestContext != null &&
        possibleRepeat) {
      return _OhWowCandidate(
        kind: ArchiveOhWowKind.returned,
        title: 'Something came back.',
        body:
            'You mentioned feeling behind again, but this time it showed up around $latestContext.',
        score: 85,
      );
    }
    if (whatFaded != null) {
      return _OhWowCandidate(
        kind: ArchiveOhWowKind.faded,
        title: 'Something may be fading.',
        body: whatFaded,
        score: 70,
      );
    }
    if (possibleRepeat && dominantPressure != null) {
      return _OhWowCandidate(
        kind: ArchiveOhWowKind.returned,
        title: 'Something came back.',
        body:
            'The pressure seems to return around ${dominantPressure.contains('say yes') ? 'saying yes before checking capacity' : dominantPressure}.',
        score: 75,
      );
    }
    if (possibleRepeat) {
      return _OhWowCandidate(
        kind: ArchiveOhWowKind.currentBelief,
        title: 'Your archive currently points to this.',
        body: beliefLine,
        score: 60,
      );
    }
    return null;
  }
}

class _OhWowCandidate {
  const _OhWowCandidate({
    required this.kind,
    required this.title,
    required this.body,
    required this.score,
  });

  final ArchiveOhWowKind kind;
  final String title;
  final String body;
  final int score;
}

extension ArchiveConfidenceBandCopy on ArchiveConfidenceBand {
  String get label => switch (this) {
    ArchiveConfidenceBand.earlySignal => 'Early signal',
    ArchiveConfidenceBand.returningThread => 'Repeated thread',
    ArchiveConfidenceBand.strongerEvidence => 'Strong pattern',
  };
}
