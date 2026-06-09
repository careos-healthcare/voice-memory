import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../contradiction_detection/contradiction_report.dart';
import '../contradiction_detection/statement_analysis.dart';
import '../theme_tracking/theme_tracker_service.dart';
import '../theme_tracking/theme_track.dart';
import 'belief_shift_models.dart';

/// Detects major, evidence-backed belief shifts across the archive timeline.
class BeliefShiftEngine {
  const BeliefShiftEngine();

  static const int minTimelineSteps = 2;
  static const int minConfidence = 58;

  BeliefShiftDetectionResult detect({
    required List<JournalEntry> entries,
    String? currentBelief,
  }) {
    if (!archiveHasMinimumEvidence(entries)) {
      return const BeliefShiftDetectionResult(reports: []);
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minTimelineSteps) {
      return const BeliefShiftDetectionResult(reports: []);
    }

    final statements = archivedStatementsFromEntries(eligible);
    final reports = <BeliefShiftReport>[];
    final seen = <String>{};

    void addReport(BeliefShiftReport? report) {
      if (report == null) return;
      if (report.confidence < minConfidence) return;
      if (!report.hasEvidenceChain) return;
      final key = '${report.kind.name}|${report.evidenceIds.join(',')}';
      if (!seen.add(key)) return;
      reports.add(report);
    }

    final contradictions = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: currentBelief,
    );
    for (final ctr in contradictions.reports) {
      addReport(_fromContradiction(ctr, statements));
    }

    addReport(_detectConfidenceShift(statements));
    addReport(_detectThemeMigration(entries, eligible, statements));

    for (final topic in _trackedTopics) {
      final chain = _statementsForTopic(statements, topic);
      if (chain.length < minTimelineSteps) continue;
      addReport(_gradualTopicShift(topic, chain));
      addReport(_repeatedLanguageShift(topic, chain));
    }

    reports.sort((a, b) => b.confidence.compareTo(a.confidence));
    return BeliefShiftDetectionResult(reports: reports.take(5).toList());
  }
}

const _trackedTopics = [
  'networking',
  'career',
  'confidence',
  'approval',
  'relationship',
  'work',
];

List<ArchivedStatement> _statementsForTopic(
  List<ArchivedStatement> statements,
  String topic,
) {
  return statements
      .where((s) => s.themes.contains(topic) || s.keywords.contains(topic))
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
}

BeliefShiftReport? _gradualTopicShift(String topic, List<ArchivedStatement> chain) {
  final distinct = _distinctByEntry(chain);
  if (distinct.length < BeliefShiftEngine.minTimelineSteps) return null;

  final first = distinct.firstWhere(
    (s) => s.isStrongNegative || s.isNegative,
    orElse: () => distinct.first,
  );
  final last = distinct.lastWhere(
    (s) => s.isPositive,
    orElse: () => distinct.last,
  );
  if (!first.at.isBefore(last.at)) return null;
  if (!first.isNegative || !last.isPositive) return null;

  final between = distinct
      .where((s) =>
          s.at.isAfter(first.at) &&
          s.at.isBefore(last.at) &&
          s.entryId != first.entryId &&
          s.entryId != last.entryId)
      .toList();

  ArchivedStatement? middle;
  if (between.isNotEmpty) {
    middle = between.firstWhere(
      (s) => s.isSoftNegative || s.softNegativeScore > 0,
      orElse: () => between[between.length ~/ 2],
    );
  }

  final steps = <BeliefShiftTimelineStep>[
    _step(first),
    if (middle != null) _step(middle),
    _step(last),
  ];

  var confidence = 60;
  if (first.isStrongNegative) confidence += 8;
  if (middle != null) confidence += 12;
  if (steps.length >= 3) confidence += 10;
  if (hasReversalPhrase(first.text, last.text)) confidence += 10;
  if (last.at.difference(first.at).inDays >= 30) confidence += 6;

  return _buildReport(
    id: 'shift-gradual-$topic',
    kind: BeliefShiftKind.gradualBeliefChange,
    steps: steps,
    confidence: confidence,
    topics: [topic],
  );
}

BeliefShiftReport? _repeatedLanguageShift(String topic, List<ArchivedStatement> chain) {
  final distinct = _distinctByEntry(chain);
  if (distinct.length < 3) return null;

  final first = distinct.first;
  final last = distinct.last;
  if (!first.isNegative || !last.isPositive) return null;

  final overlap = first.keywords.intersection(last.keywords).length;
  if (overlap >= 4) return null;

  final middles = distinct
      .where((s) => s.at.isAfter(first.at) && s.at.isBefore(last.at))
      .take(2)
      .toList();
  if (middles.isEmpty) return null;

  final steps = <BeliefShiftTimelineStep>[
    _step(first),
    ...middles.map(_step),
    _step(last),
  ];

  return _buildReport(
    id: 'shift-language-$topic',
    kind: BeliefShiftKind.repeatedLanguageChange,
    steps: steps,
    confidence: 62 + middles.length * 6,
    topics: [topic],
  );
}

BeliefShiftReport? _detectConfidenceShift(List<ArchivedStatement> statements) {
  final chain = _statementsForTopic(statements, 'confidence');
  if (chain.length < BeliefShiftEngine.minTimelineSteps) return null;

  final distinct = _distinctByEntry(chain);
  final early = distinct.take((distinct.length / 2).ceil()).toList();
  final late = distinct.skip((distinct.length / 2).ceil()).toList();
  if (early.isEmpty || late.isEmpty) return null;

  final earlyPos = early.fold<int>(0, (n, s) => n + s.positiveScore);
  final latePos = late.fold<int>(0, (n, s) => n + s.positiveScore);
  if (latePos <= earlyPos) return null;

  final first = early.firstWhere(
    (s) => s.negativeScore >= s.positiveScore,
    orElse: () => early.first,
  );
  final last = late.lastWhere((s) => s.isPositive, orElse: () => late.last);
  if (!last.isPositive) return null;

  final steps = <BeliefShiftTimelineStep>[
    _step(first),
    if (distinct.length >= 3) _step(distinct[distinct.length ~/ 2]),
    _step(last),
  ];

  return _buildReport(
    id: 'shift-confidence',
    kind: BeliefShiftKind.confidenceChange,
    steps: steps,
    confidence: 64 + (latePos - earlyPos) * 4,
    topics: const ['confidence'],
  );
}

BeliefShiftReport? _detectThemeMigration(
  List<JournalEntry> entries,
  List<JournalEntry> eligible,
  List<ArchivedStatement> statements,
) {
  final themes = const ThemeTrackerService().track(entries: entries);
  for (final theme in themes.topThemes) {
    if (theme.trend != ThemeTrend.up) continue;
    final topic = ThemeTrackerService.displayNames.entries
        .where((e) => e.value == theme.name)
        .map((e) => e.key)
        .firstOrNull;
    if (topic == null) continue;

    final chain = _statementsForTopic(statements, topic);
    final distinct = _distinctByEntry(chain);
    if (distinct.length < BeliefShiftEngine.minTimelineSteps) continue;

    final first = distinct.first;
    final last = distinct.last;
    if (!first.isNegative || !last.isPositive) continue;

    return _buildReport(
      id: 'shift-migration-$topic',
      kind: BeliefShiftKind.themeMigration,
      steps: [
        _step(first),
        if (distinct.length >= 3) _step(distinct[distinct.length ~/ 2]),
        _step(last),
      ],
      confidence: 66 + theme.frequency * 3,
      topics: [topic],
    );
  }
  return null;
}

BeliefShiftReport? _fromContradiction(
  ContradictionReport ctr,
  List<ArchivedStatement> statements,
) {
  final earlier = statements
      .where((s) => s.entryId == ctr.originalEntryId)
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final later = statements
      .where((s) => s.entryId == ctr.conflictingEntryId)
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  if (earlier.isEmpty || later.isEmpty) return null;

  final first = earlier.first;
  final last = later.last;
  final topic = ctr.sharedThemes.isNotEmpty
      ? ctr.sharedThemes.first
      : first.primaryTopic() ?? 'belief';

  final between = statements
      .where((s) =>
          s.at.isAfter(first.at) &&
          s.at.isBefore(last.at) &&
          (s.themes.contains(topic) ||
              s.keywords.contains(topic) ||
              s.sharesTopicWith(first)))
      .toList();

  final middles = _distinctByEntry(between)
      .where((s) => s.entryId != first.entryId && s.entryId != last.entryId)
      .toList();

  final steps = <BeliefShiftTimelineStep>[
    _step(first, overrideText: ctr.originalStatement),
    if (middles.isNotEmpty) _step(middles.first),
    _step(last, overrideText: ctr.conflictingStatement),
  ];

  final kind = switch (ctr.kind) {
    ContradictionKind.gradualShift => BeliefShiftKind.gradualBeliefChange,
    ContradictionKind.changedLanguage => BeliefShiftKind.repeatedLanguageChange,
    ContradictionKind.reversedTheme => BeliefShiftKind.themeMigration,
    _ => BeliefShiftKind.gradualBeliefChange,
  };

  return _buildReport(
    id: 'shift-ctr-${ctr.id}',
    kind: kind,
    steps: steps,
    confidence: ctr.confidenceScore,
    topics: ctr.sharedThemes,
  );
}

List<ArchivedStatement> _distinctByEntry(List<ArchivedStatement> chain) {
  final seen = <String>{};
  final out = <ArchivedStatement>[];
  for (final s in chain) {
    if (!seen.add(s.entryId)) continue;
    out.add(s);
  }
  return out;
}

BeliefShiftTimelineStep _step(ArchivedStatement s, {String? overrideText}) {
  return BeliefShiftTimelineStep(
    beliefText: overrideText ?? s.text,
    entryId: s.entryId,
    recordedAt: s.at,
  );
}

BeliefShiftReport? _buildReport({
  required String id,
  required BeliefShiftKind kind,
  required List<BeliefShiftTimelineStep> steps,
  required int confidence,
  required List<String> topics,
}) {
  final deduped = <BeliefShiftTimelineStep>[];
  final seenIds = <String>{};
  for (final step in steps) {
    if (!seenIds.add(step.entryId)) continue;
    deduped.add(step);
  }
  if (deduped.length < BeliefShiftEngine.minTimelineSteps) return null;

  final evidenceIds = deduped.map((s) => s.entryId).toList();
  return BeliefShiftReport(
    id: id,
    originalBelief: deduped.first.beliefText,
    newBelief: deduped.last.beliefText,
    confidence: confidence.clamp(0, 100),
    evolutionTimeline: deduped,
    evidenceIds: evidenceIds,
    kind: kind,
    sharedTopics: topics,
  );
}
