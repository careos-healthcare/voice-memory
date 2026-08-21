import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/record/early_behavior_loop_copy.dart';
import 'package:archiveme_mobile/features/record/early_behavior_loop_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/product/consumer_copy_guard.dart';

/// Deterministic behaviour-loop detection from the latest 2–3 saved moments.
class EarlyBehaviorLoopEngine {
  const EarlyBehaviorLoopEngine();

  static const String _fallbackEvidence = EarlyBehaviorLoopCopy.evidenceFallback;

  static final _loops = <_LoopDefinition>[
    const _LoopDefinition(
      id: 'capacity',
      title: 'This looks like a capacity loop',
      loopLine:
          'Pressure shows up, then you say yes before checking your capacity.',
      triggerLine: 'Trigger: someone needs something from you.',
      behaviorLine: 'What you do: agree first, deal with the cost later.',
      costLine: 'Cost: you end up carrying more than you had space for.',
      nextCheckLine: 'Tomorrow, notice the moment before you agree.',
      signals: [
        'said yes',
        'agree',
        'agreed',
        'no capacity',
        'too much',
        'overloaded',
        "can't say no",
        'cant say no',
        'let them down',
        'guilty',
      ],
      weakSingletons: {'guilty', 'agree', 'agreed'},
      strongPairs: [
        ['said yes', 'no capacity'],
        ['said yes', 'too much'],
        ['agree', 'no capacity'],
        ['agreed', 'no capacity'],
      ],
      evidencePriority: ['said yes', 'no capacity', 'too much', 'agreed'],
    ),
    const _LoopDefinition(
      id: 'work_pressure',
      title: 'This looks like a work pressure loop',
      loopLine:
          'Work pressure builds, then your mind stays with it after the moment has passed.',
      triggerLine: 'Trigger: deadlines, messages, or work demands pile up.',
      behaviorLine: 'What you do: stay switched on even after the task ends.',
      costLine:
          'Cost: work keeps running in your head when you wanted to stop.',
      nextCheckLine:
          'Tomorrow, notice whether work is still in your head after the task ends.',
      signals: [
        'work pressure',
        'deadline',
        'manager',
        'meeting',
        'email',
        'pressure',
        'urgent',
        'busy',
        'behind',
        'work',
      ],
      weakSingletons: {'work', 'busy', 'email', 'meeting'},
      strongPairs: [
        ['work', 'pressure'],
        ['work', 'deadline'],
        ['deadline', 'pressure'],
        ['manager', 'email'],
      ],
      evidencePriority: ['work pressure', 'deadline', 'pressure', 'urgent'],
    ),
    const _LoopDefinition(
      id: 'avoidance',
      title: 'This looks like an avoidance loop',
      loopLine: 'You notice the task, then delay it until it feels heavier.',
      triggerLine: 'Trigger: something you know you should start.',
      behaviorLine: 'What you do: put it off until later.',
      costLine: 'Cost: the task feels heavier each time you delay it.',
      nextCheckLine: 'Tomorrow, notice the first moment you avoid starting.',
      signals: [
        'put off',
        'putting off',
        'avoid',
        'delayed',
        'later',
        'procrastinate',
        'ignored',
        "couldn't start",
        'couldnt start',
        'stuck',
      ],
      weakSingletons: {'later', 'stuck'},
      strongPairs: [
        ['put off', 'stuck'],
        ['avoid', 'later'],
        ['procrastinate', 'stuck'],
      ],
      evidencePriority: ['put off', 'avoid', 'procrastinate', 'stuck'],
    ),
    const _LoopDefinition(
      id: 'rumination',
      title: 'This looks like a rumination loop',
      loopLine: 'The moment ends, but your mind keeps replaying it.',
      triggerLine: 'Trigger: something unresolved from the day.',
      behaviorLine: 'What you do: replay it again and again in your head.',
      costLine: 'Cost: your mind stays with it after the moment has passed.',
      nextCheckLine: 'Tomorrow, notice what your mind replays first.',
      signals: [
        'kept thinking',
        'overthinking',
        'replay',
        "can't stop thinking",
        'cant stop thinking',
        'again and again',
        'worry',
      ],
      weakSingletons: {'worry', 'replay'},
      strongPairs: [
        ['kept thinking', 'again'],
        ['overthinking', 'again'],
        ['worry', 'again and again'],
      ],
      evidencePriority: [
        'kept thinking',
        'overthinking',
        "can't stop thinking",
        'again and again',
      ],
    ),
    const _LoopDefinition(
      id: 'suppression',
      title: 'This looks like a keep-it-private loop',
      loopLine:
          'You feel something, then keep it private instead of saying it clearly.',
      triggerLine: 'Trigger: a moment where someone asks how you are.',
      behaviorLine: 'What you do: say you are fine and hold the rest in.',
      costLine: 'Cost: what you feel stays unspoken.',
      nextCheckLine:
          "Tomorrow, notice where you say 'fine' but mean something else.",
      signals: [
        'pretended',
        "didn't say",
        'didnt say',
        'kept quiet',
        'bottled',
        'held it in',
        'smiled',
        'fine',
      ],
      weakSingletons: {'fine', 'smiled'},
      strongPairs: [
        ['fine', "didn't say"],
        ['fine', 'kept quiet'],
        ['pretended', 'fine'],
        ['bottled', 'held it in'],
      ],
      evidencePriority: ['kept quiet', "didn't say", 'held it in', 'pretended'],
    ),
  ];

  EarlyBehaviorLoopInsight build(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return EarlyBehaviorLoopInsight.none;

    final window = eligible.length <= 3
        ? eligible
        : eligible.sublist(eligible.length - 3);
    final texts = window.map(_entryText).where((t) => t.isNotEmpty).toList();
    if (texts.length < 2) return EarlyBehaviorLoopInsight.none;

    _LoopMatch? best;
    for (final loop in _loops) {
      final match = _scoreLoop(loop, texts);
      if (match == null) continue;
      if (best == null || match.score > best.score) {
        best = match;
      }
    }
    if (best == null) return EarlyBehaviorLoopInsight.none;

    final def = best.definition;
    final evidenceLine = _evidenceLine(def, texts, best.matchedPhrases);
    final confidenceLabel = 'Early signal — based on ${texts.length} moments';

    final insight = EarlyBehaviorLoopInsight(
      title: def.title,
      loopLine: def.loopLine,
      triggerLine: def.triggerLine,
      behaviorLine: def.behaviorLine,
      costLine: def.costLine,
      evidenceLine: evidenceLine,
      nextCheckLine: def.nextCheckLine,
      confidenceLabel: confidenceLabel,
      shouldShow: true,
    );

    if (!_isSafeCopy(insight)) return EarlyBehaviorLoopInsight.none;
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

  _LoopMatch? _scoreLoop(_LoopDefinition def, List<String> texts) {
    final entryMatches = <int, _EntryMatch>{};
    for (var i = 0; i < texts.length; i++) {
      final match = _entryMatch(def, texts[i]);
      if (match != null) entryMatches[i] = match;
    }
    if (entryMatches.isEmpty) return null;

    final supportingEntries = entryMatches.length;
    final hasStrongEntry = entryMatches.values.any((m) => m.isStrong);
    final hasAdjacentPair =
        supportingEntries >= 2 &&
        entryMatches.values.any((m) => m.isStrong || m.nonWeakCount >= 2);

    final qualifies =
        supportingEntries >= 2 ||
        (hasStrongEntry &&
            supportingEntries >= 1 &&
            texts.length >= 2 &&
            _hasAdjacentSupport(def, texts, entryMatches));
    if (!qualifies) return null;

    if (supportingEntries < 2 && !hasStrongEntry) return null;
    if (supportingEntries == 1 && !hasStrongEntry) return null;

    final allPhrases = entryMatches.values
        .expand((m) => m.matchedSignals)
        .toSet()
        .toList();
    final evidencePhrases = _pickEvidencePhrases(def, allPhrases);
    if (evidencePhrases.isEmpty) return null;

    final score =
        supportingEntries * 10 +
        (hasStrongEntry ? 20 : 0) +
        allPhrases.length +
        (hasAdjacentPair ? 5 : 0);

    return _LoopMatch(
      definition: def,
      score: score,
      matchedPhrases: evidencePhrases,
    );
  }

  bool _hasAdjacentSupport(
    _LoopDefinition def,
    List<String> texts,
    Map<int, _EntryMatch> entryMatches,
  ) {
    if (entryMatches.length >= 2) return true;
    final strongIndex = entryMatches.entries
        .firstWhere(
          (e) => e.value.isStrong,
          orElse: () => entryMatches.entries.first,
        )
        .key;
    for (var i = 0; i < texts.length; i++) {
      if (i == strongIndex) continue;
      final lower = texts[i].toLowerCase();
      if (def.signals.any(lower.contains)) return true;
    }
    return false;
  }

  _EntryMatch? _entryMatch(_LoopDefinition def, String text) {
    final lower = text.toLowerCase();
    final matched = <String>[];
    for (final signal in def.signals) {
      if (lower.contains(signal)) matched.add(signal);
    }
    if (matched.isEmpty) return null;

    final isStrong = def.strongPairs.any(
      (pair) => pair.every(lower.contains),
    );
    final nonWeak = matched
        .where((s) => !def.weakSingletons.contains(s))
        .toList();

    if (!isStrong && matched.every(def.weakSingletons.contains)) {
      return null;
    }
    if (!isStrong && nonWeak.isEmpty) return null;

    return _EntryMatch(
      matchedSignals: matched,
      isStrong: isStrong,
      nonWeakCount: nonWeak.length,
    );
  }

  List<String> _pickEvidencePhrases(_LoopDefinition def, List<String> matched) {
    final picked = <String>[];
    for (final priority in def.evidencePriority) {
      if (!matched.any((m) => m == priority || m.contains(priority))) continue;
      if (picked.contains(priority)) continue;
      picked.add(_capPhrase(priority));
      if (picked.length >= 3) break;
    }
    for (final signal in matched) {
      if (picked.length >= 3) break;
      if (picked.contains(_capPhrase(signal))) continue;
      if (def.weakSingletons.contains(signal)) continue;
      picked.add(_capPhrase(signal));
    }
    return picked;
  }

  String _capPhrase(String phrase) {
    final words = phrase.split(RegExp(r'\s+'));
    if (words.length <= 7) return phrase;
    return words.take(7).join(' ');
  }

  String _evidenceLine(
    _LoopDefinition def,
    List<String> texts,
    List<String> phrases,
  ) {
    if (phrases.isEmpty) return _fallbackEvidence;

    final quoted = phrases
        .map((p) => _quoteFromEntries(p, texts) ?? p)
        .map(_capPhrase)
        .toList();

    if (quoted.isEmpty) return _fallbackEvidence;
    if (quoted.length == 1) {
      return "Your words included '${quoted.first}'.";
    }
    if (quoted.length == 2) {
      return "Your words included '${quoted.first}' and '${quoted.second}'.";
    }
    return "Your words included '${quoted[0]}', '${quoted[1]}', and '${quoted[2]}'.";
  }

  String? _quoteFromEntries(String phrase, List<String> texts) {
    for (final text in texts) {
      final lower = text.toLowerCase();
      final index = lower.indexOf(phrase.toLowerCase());
      if (index < 0) continue;
      return text.substring(index, index + phrase.length).trim();
    }
    return phrase;
  }

  bool _isSafeCopy(EarlyBehaviorLoopInsight insight) {
    final blob =
        '${insight.title} ${insight.loopLine} ${insight.triggerLine} '
                '${insight.behaviorLine} ${insight.costLine} ${insight.evidenceLine} '
                '${insight.nextCheckLine} ${insight.confidenceLabel}'
            .toLowerCase();
    for (final banned in EarlyBehaviorLoopCopy.bannedTerms) {
      if (_containsBannedTerm(blob, banned)) return false;
    }
    return insight.loopLine.isNotEmpty &&
        insight.evidenceLine.isNotEmpty &&
        insight.nextCheckLine.isNotEmpty;
  }

  bool _containsBannedTerm(String blob, String term) {
    final trimmed = term.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    if (trimmed == 'ai') {
      return RegExp(r'\bai\b').hasMatch(blob);
    }
    return blob.contains(trimmed);
  }
}

extension on List<String> {
  String get second => length > 1 ? this[1] : '';
}

class _LoopDefinition {
  const _LoopDefinition({
    required this.id,
    required this.title,
    required this.loopLine,
    required this.triggerLine,
    required this.behaviorLine,
    required this.costLine,
    required this.nextCheckLine,
    required this.signals,
    required this.weakSingletons,
    required this.strongPairs,
    required this.evidencePriority,
  });

  final String id;
  final String title;
  final String loopLine;
  final String triggerLine;
  final String behaviorLine;
  final String costLine;
  final String nextCheckLine;
  final List<String> signals;
  final Set<String> weakSingletons;
  final List<List<String>> strongPairs;
  final List<String> evidencePriority;
}

class _LoopMatch {
  const _LoopMatch({
    required this.definition,
    required this.score,
    required this.matchedPhrases,
  });

  final _LoopDefinition definition;
  final int score;
  final List<String> matchedPhrases;
}

class _EntryMatch {
  const _EntryMatch({
    required this.matchedSignals,
    required this.isStrong,
    required this.nonWeakCount,
  });

  final List<String> matchedSignals;
  final bool isStrong;
  final int nonWeakCount;
}