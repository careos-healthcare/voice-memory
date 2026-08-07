import '../../models/journal_entry.dart';
import '../archive_evidence/archive_belief_thread_copy.dart';
import '../archive_evidence/archive_belief_thread_engine.dart';
import '../archive_evidence/archive_belief_thread_model.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_evidence/archive_intelligence_tier.dart';
import '../retention/second_session_signal_model.dart';
import 'pattern_display_copy_gate.dart';
import 'patterns_human_copy.dart';

/// Engine output → human copy → display gate → UI-ready bundle.
abstract class PatternIntelligencePipeline {
  PatternIntelligencePipeline._();

  static PatternIntelligenceDisplayBundle build(
    List<JournalEntry> entries, {
    ArchiveIntelligenceTier tier = ArchiveIntelligenceTier.freeMedium,
  }) {
    const beliefEngine = ArchiveBeliefThreadEngine();
    const weeklyEngine = WeeklyWhatChangedReviewEngine();
    const heuristics = ArchiveEvidenceHeuristics();

    final analysis = heuristics.analyze(entries, tier: tier);
    final beliefRaw = beliefEngine.build(entries, tier: tier);
    final weeklyRaw = weeklyEngine.build(entries, tier: tier);
    final ohWowRaw = beliefEngine.buildOhWow(entries, tier: tier);

    final input = PatternHumanCopyInput.fromEntries(
      entries,
      analysis: analysis,
    );
    final humanCopy = PatternHumanCopyResolver.resolve(input);

    final belief = _beliefFromHumanCopy(humanCopy, beliefRaw);
    final ohWow = _ohWowFromHumanCopy(humanCopy, beliefRaw, ohWowRaw);
    final weekly = _weeklyFromHumanCopy(humanCopy, weeklyRaw);

    final sanitized = PatternDisplayCopyGate.sanitizeIntelligence(
      belief: belief,
      weekly: weekly,
      ohWow: ohWow,
    );

    final resolvedHumanCopy = sanitized.usedBlockFallback
        ? PatternHumanCopyBundle.fallback(evidenceCount: input.evidenceCount)
        : humanCopy;

    return PatternIntelligenceDisplayBundle(
      belief: sanitized.belief,
      ohWow: sanitized.ohWow,
      weekly: sanitized.weekly,
      humanCopy: resolvedHumanCopy,
      usedBlockFallback: sanitized.usedBlockFallback,
    );
  }

  static SecondSessionComparison applyHumanCopyToComparison(
    SecondSessionComparison comparison,
    PatternHumanCopyInput input,
  ) {
    if (!comparison.hasEnoughData) return comparison;

    final humanCopy = PatternHumanCopyResolver.resolve(input);
    return SecondSessionComparison(
      hasEnoughData: true,
      title: comparison.title,
      body: comparison.body,
      whatRepeated: humanCopy.evidenceBody,
      whatChanged: humanCopy.whatChangedBody,
      whatToTestNext: humanCopy.reflectivePrompt == null
          ? humanCopy.whatToTestBody
          : '${humanCopy.whatToTestBody}\n\n${humanCopy.reflectivePrompt}',
      previousSignalLabel: comparison.previousSignalLabel,
      latestSignalLabel: comparison.latestSignalLabel,
      possibleRepeat: comparison.possibleRepeat,
    );
  }

  static ArchiveBeliefThread _beliefFromHumanCopy(
    PatternHumanCopyBundle copy,
    ArchiveBeliefThread raw,
  ) {
    if (!raw.hasEnoughData) return raw;

    final whatToTest = copy.reflectivePrompt == null
        ? copy.whatToTestBody
        : '${copy.whatToTestBody}\n\n${copy.reflectivePrompt}';

    return ArchiveBeliefThread(
      hasEnoughData: true,
      suggestionId: raw.suggestionId,
      currentBelief: copy.mainObservation,
      evidenceLine: copy.exactEvidencePhrases.isNotEmpty
          ? copy.evidenceLabel
          : copy.evidenceBody,
      whatChanged: copy.whatChangedBody,
      whatToTest: whatToTest,
      timeline: _timelineFromHumanCopy(copy, raw),
      worthWatchingLine: copy.worthWatchingLine,
      previousBeliefLine: raw.previousBeliefLine,
      whatReturnedLine: raw.whatReturnedLine,
      whatFadedLine: raw.whatFadedLine,
      confidenceBand: raw.confidenceBand,
      evidenceSnippets: copy.exactEvidencePhrases.isNotEmpty
          ? copy.exactEvidencePhrases
          : raw.evidenceSnippets,
      isProDepth: raw.isProDepth,
    );
  }

  static ArchiveOhWowMoment _ohWowFromHumanCopy(
    PatternHumanCopyBundle copy,
    ArchiveBeliefThread beliefRaw,
    ArchiveOhWowMoment ohWowRaw,
  ) {
    if (!beliefRaw.hasEnoughData) return ArchiveOhWowMoment.none;
    if (!ohWowRaw.hasMoment && copy.kind == PatternHumanCopyKind.fallback) {
      return ArchiveOhWowMoment(
        hasMoment: true,
        kind: ArchiveOhWowKind.currentBelief,
        title: copy.heroTitle,
        body: copy.heroBody,
        suggestionId: 'human_copy_hero',
      );
    }
    if (!ohWowRaw.hasMoment) {
      return ArchiveOhWowMoment(
        hasMoment: true,
        kind: ArchiveOhWowKind.currentBelief,
        title: copy.heroTitle,
        body: copy.heroBody,
        suggestionId: 'human_copy_hero',
      );
    }
    return ArchiveOhWowMoment(
      hasMoment: true,
      kind: ohWowRaw.kind,
      title: copy.heroTitle,
      body: copy.heroBody,
      suggestionId: ohWowRaw.suggestionId,
    );
  }

  static WeeklyWhatChangedReview _weeklyFromHumanCopy(
    PatternHumanCopyBundle copy,
    WeeklyWhatChangedReview raw,
  ) {
    if (!raw.hasReview) return raw;
    return WeeklyWhatChangedReview(
      hasReview: true,
      whatKeptReturning: copy.evidenceBody,
      whatChanged: copy.whatChangedBody,
      whatToTestNext: copy.whatToTestBody,
      whatFaded: raw.whatFaded,
      isProDepth: raw.isProDepth,
    );
  }

  static List<ArchiveEvidenceTimelineStep> _timelineFromHumanCopy(
    PatternHumanCopyBundle copy,
    ArchiveBeliefThread raw,
  ) {
    if (raw.timeline.isEmpty) {
      return [
        ArchiveEvidenceTimelineStep(
          label: copy.firstAppearedLabel,
          body: copy.firstAppearedBody,
        ),
        ArchiveEvidenceTimelineStep(
          label: copy.returnedLabel,
          body: copy.returnedBody,
        ),
        ArchiveEvidenceTimelineStep(
          label: copy.currentSignalLabel,
          body: copy.currentSignalBody,
        ),
      ];
    }

    final steps = <ArchiveEvidenceTimelineStep>[];
    for (final step in raw.timeline) {
      final label = switch (step.label) {
        ArchiveBeliefThreadCopy.timelineFirstAppeared =>
          copy.firstAppearedLabel,
        ArchiveBeliefThreadCopy.timelineReturned => copy.returnedLabel,
        ArchiveBeliefThreadCopy.timelineCurrentSignal =>
          copy.currentSignalLabel,
        _ => step.label,
      };
      final body = switch (step.label) {
        ArchiveBeliefThreadCopy.timelineFirstAppeared => copy.firstAppearedBody,
        ArchiveBeliefThreadCopy.timelineReturned => copy.returnedBody,
        ArchiveBeliefThreadCopy.timelineCurrentSignal => copy.currentSignalBody,
        _ => step.body,
      };
      steps.add(ArchiveEvidenceTimelineStep(label: label, body: body));
    }
    return steps;
  }
}
