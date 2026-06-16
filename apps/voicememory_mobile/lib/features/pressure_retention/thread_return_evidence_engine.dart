import '../memory/memory_authority_framing_engine.dart';
import '../memory/memory_control_model.dart';
import '../memory/memory_governance_policy.dart';
import '../memory/memory_priority_governance.dart';
import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'thread_return_evidence_model.dart';

/// Detects one repeated thread across the user's pressure entries and builds
/// the evidence-backed continuity behind it.
///
/// Pure and deterministic. Threads are detected only from real overlap in the
/// user's own entries — shared contexts, repeated free-text words, or the
/// same pressure option theme. Nothing is fabricated: every snippet is the
/// user's exact saved text, and every count maps to real entry ids.
///
/// Status rules (occurrences sorted oldest → newest):
/// - Fewer than 2 occurrences → no evidence, nothing is shown.
/// - Exactly 2 occurrences → early signal only; never stronger language.
/// - 3+ and the newest occurrence is today → "returned today".
/// - 3+ and the older half of the window holds more occurrences than the
///   recent half → "may be fading".
/// - 3+ and the recent half holds more → "may be building".
/// - 3+ spread evenly with the latest in the recent half → cautious
///   "came back recently".
class ThreadReturnEvidenceEngine {
  const ThreadReturnEvidenceEngine();

  /// Filler plus generic app words — a thread named after these would read
  /// like template copy, not the user's own evidence.
  static const Set<String> _ignoredWords = {
    'the',
    'and',
    'for',
    'that',
    'this',
    'with',
    'was',
    'were',
    'will',
    'would',
    'wont',
    "won't",
    'its',
    "it's",
    'not',
    'but',
    'had',
    'have',
    'has',
    'did',
    'does',
    'about',
    'from',
    'they',
    'them',
    'when',
    'then',
    'than',
    'what',
    'how',
    'why',
    'who',
    'all',
    'too',
    'very',
    'just',
    'like',
    'get',
    'got',
    'gets',
    'into',
    'out',
    'off',
    'might',
    'maybe',
    'could',
    'should',
    'because',
    'being',
    'been',
    'still',
    'even',
    'more',
    'again',
    'myself',
    'dont',
    "don't",
    'cant',
    "can't",
    'ill',
    "i'll",
    'pressure',
    'moment',
    'moments',
    'pattern',
    'patterns',
    'archive',
    'entry',
    'entries',
    'check',
    'checkin',
    'app',
    'archiveme',
    'feel',
    'feels',
    'felt',
    'feeling',
  };

  /// [now] is injectable for tests; "returned today" compares against it.
  ThreadReturnEvidence build(
    List<PressureCheckInRecord> records, {
    DateTime? now,
    int? entryCount,
  }) {
    final totalEntryCount = entryCount ?? records.length;
    final governance = MemoryGovernancePolicy.evaluate(
      cardType: MemoryCardType.threadReturn,
      records: records,
      entryCount: totalEntryCount,
      now: now,
    );
    if (!MemoryGovernancePolicy.permitsEngineBuild(governance)) {
      return ThreadReturnEvidence.none();
    }
    // Authority framing: memory scope eligibility, retrieval scoring,
    // and the explicit authority/influence decision all run before any
    // evidence may back a claim. Records stay in the archive untouched
    // either way; this card renders only when the frame's influence is
    // compare or high authority.
    final framing = const MemoryAuthorityFramingEngine().frame(
      records,
      now: now,
      cardType: MemoryCardType.threadReturn,
    );
    if (!framing.allowsConnectionClaims) return ThreadReturnEvidence.none();
    final priority = MemoryPriorityGovernance.evaluate(
      cardType: MemoryCardType.threadReturn,
      records: records,
      governance: governance,
      framing: framing,
      now: now,
      entryCount: totalEntryCount,
      trackAnalytics: false,
    );
    if (!MemoryPriorityGovernance.permitsEngineBuild(
      priority,
      confirmationPending: governance.requiresUserConfirmation,
    )) {
      return ThreadReturnEvidence.none();
    }
    final eligible = MemoryPriorityGovernance.filterCandidates(
      framing.candidates,
      cardType: MemoryCardType.threadReturn,
      priority: priority,
      anchor: now,
      confirmationPending: governance.requiresUserConfirmation,
    );
    if (eligible.length < ThreadReturnEvidence.minOccurrences) {
      return ThreadReturnEvidence.none();
    }

    final thread = _dominantThread(eligible);
    if (thread == null) return ThreadReturnEvidence.none();

    final occurrences = [...thread.entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final count = occurrences.length;
    final first = occurrences.first.createdAt;
    final last = occurrences.last.createdAt;
    final daysWindow = last.difference(first).inDays + 1;
    final clock = now ?? DateTime.now();

    final status = _status(occurrences, count, clock);

    return ThreadReturnEvidence(
      hasEvidence: true,
      headline: _headline(status, occurrences.last.createdAt, clock),
      namedLine: _namedLine(thread),
      summaryLine: _summaryLine(status, thread.label, count, daysWindow),
      status: status,
      occurrenceCount: count,
      daysWindow: daysWindow,
      sourceTerms: _sourceTerms(thread, occurrences),
      evidenceSnippets: _snippets(occurrences),
      entryIds: occurrences.map((r) => r.entryId).toList(),
      confidenceLabel: _confidenceLabel(count),
      followUpPrompt: _followUpPrompt(status),
      followUpCtaLabel: _followUpCtaLabel(status),
    );
  }

  /// Light affect labeling: names the thread with the user's own term.
  /// Naming only — never a claim of processing, healing, or resolution.
  String _namedLine(_ThreadCandidate thread) {
    final term = thread.term.trim();
    if (term.isEmpty) return ThreadReturnEvidence.genericNamedLine;
    // Option themes ("stopping", "feeling behind") read as pressure, not as
    // a thread noun.
    if (thread.priority == 2) return 'You named the pressure around $term.';
    return 'You named the $term thread.';
  }

  /// Turns the evidence into a next action: record what happened this time.
  String _followUpCtaLabel(ThreadReturnStatus status) {
    switch (status) {
      case ThreadReturnStatus.returned:
        return ThreadReturnEvidence.returnedFollowUpCta;
      case ThreadReturnStatus.building:
        return ThreadReturnEvidence.buildingFollowUpCta;
      case ThreadReturnStatus.fading:
        return ThreadReturnEvidence.fadingFollowUpCta;
      case ThreadReturnStatus.earlySignal:
        return ThreadReturnEvidence.earlySignalFollowUpCta;
    }
  }

  String _followUpPrompt(ThreadReturnStatus status) {
    switch (status) {
      case ThreadReturnStatus.returned:
        return ThreadReturnEvidence.returnedFollowUpPrompt;
      case ThreadReturnStatus.building:
        return ThreadReturnEvidence.buildingFollowUpPrompt;
      case ThreadReturnStatus.fading:
        return ThreadReturnEvidence.fadingFollowUpPrompt;
      case ThreadReturnStatus.earlySignal:
        return ThreadReturnEvidence.earlySignalFollowUpPrompt;
    }
  }

  ThreadReturnStatus _status(
    List<PressureCheckInRecord> occurrences,
    int count,
    DateTime clock,
  ) {
    if (count < ThreadReturnEvidence.minOccurrencesForStrongLanguage) {
      return ThreadReturnStatus.earlySignal;
    }
    if (_sameDay(occurrences.last.createdAt, clock)) {
      return ThreadReturnStatus.returned;
    }

    // Split the occurrence window at its midpoint: older vs recent half.
    final first = occurrences.first.createdAt;
    final last = occurrences.last.createdAt;
    final midpoint = first.add(
      Duration(milliseconds: last.difference(first).inMilliseconds ~/ 2),
    );
    var older = 0;
    var recent = 0;
    for (final record in occurrences) {
      if (record.createdAt.isBefore(midpoint)) {
        older++;
      } else {
        recent++;
      }
    }
    if (older > recent) return ThreadReturnStatus.fading;
    if (recent > older) return ThreadReturnStatus.building;
    return ThreadReturnStatus.returned;
  }

  String _headline(ThreadReturnStatus status, DateTime newest, DateTime clock) {
    switch (status) {
      case ThreadReturnStatus.returned:
        return _sameDay(newest, clock)
            ? ThreadReturnEvidence.returnedTodayHeadline
            : ThreadReturnEvidence.returnedHeadline;
      case ThreadReturnStatus.fading:
        return ThreadReturnEvidence.fadingHeadline;
      case ThreadReturnStatus.building:
        return ThreadReturnEvidence.buildingHeadline;
      case ThreadReturnStatus.earlySignal:
        return ThreadReturnEvidence.earlySignalHeadline;
    }
  }

  String _summaryLine(
    ThreadReturnStatus status,
    String threadLabel,
    int count,
    int daysWindow,
  ) {
    switch (status) {
      case ThreadReturnStatus.fading:
        return '$threadLabel appeared less often in your recent entries.';
      case ThreadReturnStatus.earlySignal:
        return '$threadLabel has appeared $count times in $daysWindow days. '
            'Too early to call it a pattern.';
      case ThreadReturnStatus.returned:
      case ThreadReturnStatus.building:
        return '$threadLabel has appeared $count times in $daysWindow days.';
    }
  }

  String _confidenceLabel(int count) {
    if (count >= 5) return ThreadReturnEvidence.strongRepeatedSignalConfidence;
    if (count >= 3) return ThreadReturnEvidence.repeatedSignalConfidence;
    return ThreadReturnEvidence.earlySignalConfidence;
  }

  /// Primary term first, then other terms that repeated within the thread
  /// entries, capped at [ThreadReturnEvidence.maxTerms].
  List<String> _sourceTerms(
    _ThreadCandidate thread,
    List<PressureCheckInRecord> occurrences,
  ) {
    final terms = <String>[thread.term];
    final seen = <String>{thread.term.toLowerCase()};
    final extras = <String>[
      ..._repeatedContextLabels(occurrences),
      ..._repeatedFreeTextWords(occurrences),
    ];
    for (final extra in extras) {
      if (terms.length >= ThreadReturnEvidence.maxTerms) break;
      if (seen.add(extra.toLowerCase())) terms.add(extra);
    }
    return terms;
  }

  /// The user's exact saved words (fear / stop-cost note), newest entries
  /// first, capped at [ThreadReturnEvidence.maxSnippets]. Never fabricated.
  List<String> _snippets(List<PressureCheckInRecord> occurrences) {
    final snippets = <String>[];
    final seen = <String>{};
    for (final record in occurrences.reversed) {
      for (final text in [record.fear, record.stopCostNote]) {
        final snippet = text?.trim() ?? '';
        if (snippet.isEmpty) continue;
        if (snippets.length >= ThreadReturnEvidence.maxSnippets)
          return snippets;
        if (seen.add(snippet.toLowerCase())) snippets.add(snippet);
      }
    }
    return snippets;
  }

  /// The strongest repeated signal across entries: a shared context, a
  /// repeated free-text word, or the same pressure option theme. Highest
  /// occurrence count wins; contexts beat words beat option themes on ties.
  _ThreadCandidate? _dominantThread(List<PressureCheckInRecord> records) {
    final candidates = <_ThreadCandidate>[];

    final contextCounts = <String, List<PressureCheckInRecord>>{};
    for (final record in records) {
      for (final context in record.contexts) {
        contextCounts.putIfAbsent(context.label, () => []).add(record);
      }
    }
    contextCounts.forEach((label, entries) {
      if (entries.length >= 2) {
        candidates.add(
          _ThreadCandidate(
            label: '$label pressure',
            term: label.toLowerCase(),
            priority: 0,
            entries: entries,
          ),
        );
      }
    });

    final wordEntries = <String, List<PressureCheckInRecord>>{};
    for (final record in records) {
      for (final word in _entryWords(record)) {
        wordEntries.putIfAbsent(word, () => []).add(record);
      }
    }
    wordEntries.forEach((word, entries) {
      if (entries.length >= 2) {
        candidates.add(
          _ThreadCandidate(
            label: '${_capitalize(word)} pressure',
            term: word,
            priority: 1,
            entries: entries,
          ),
        );
      }
    });

    final optionEntries = <String, List<PressureCheckInRecord>>{};
    for (final record in records) {
      optionEntries.putIfAbsent(record.optionId, () => []).add(record);
    }
    optionEntries.forEach((optionId, entries) {
      final theme = _optionTheme(optionId);
      if (entries.length >= 2 && theme != null) {
        candidates.add(
          _ThreadCandidate(
            label: 'Pressure around $theme',
            term: theme,
            priority: 2,
            entries: entries,
          ),
        );
      }
    });

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byCount = b.entries.length.compareTo(a.entries.length);
      if (byCount != 0) return byCount;
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) return byPriority;
      return a.label.compareTo(b.label);
    });
    return candidates.first;
  }

  /// Distinct meaningful words in one entry's free text — counted once per
  /// entry so one wordy note cannot fake repetition.
  Set<String> _entryWords(PressureCheckInRecord record) {
    final text = '${record.fear ?? ''} ${record.stopCostNote ?? ''}';
    final words = <String>{};
    for (final raw in text.toLowerCase().split(RegExp(r"[^a-z']+"))) {
      final word = raw.trim();
      if (word.length < 3 || _ignoredWords.contains(word)) continue;
      words.add(word);
    }
    return words;
  }

  List<String> _repeatedContextLabels(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final context in record.contexts) {
        final label = context.label.toLowerCase();
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return _sortedRepeated(counts);
  }

  List<String> _repeatedFreeTextWords(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final word in _entryWords(record)) {
        counts[word] = (counts[word] ?? 0) + 1;
      }
    }
    return _sortedRepeated(counts);
  }

  List<String> _sortedRepeated(Map<String, int> counts) {
    final repeated = counts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return repeated.map((e) => e.key).toList();
  }

  /// Short hedged theme for a repeated pressure option — no diagnosis.
  String? _optionTheme(String? optionId) {
    switch (PressureCheckInOption.fromId(optionId)) {
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'feeling behind';
      case PressureCheckInOption.couldNotStop:
        return 'stopping';
      case PressureCheckInOption.hadToProveEnough:
        return 'proving yourself';
      case PressureCheckInOption.guiltyResting:
        return 'guilt about resting';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'needing to feel productive';
      case null:
        return null;
    }
  }

  String _capitalize(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ThreadCandidate {
  const _ThreadCandidate({
    required this.label,
    required this.term,
    required this.priority,
    required this.entries,
  });

  /// Consumer-facing thread name, e.g. "Work pressure".
  final String label;

  /// Chip-friendly term, e.g. "work".
  final String term;

  /// Tie-break order: contexts (0) before words (1) before option themes (2).
  final int priority;

  final List<PressureCheckInRecord> entries;
}
