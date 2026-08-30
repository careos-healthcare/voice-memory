import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Route for the belief evidence drilldown screen.
abstract final class BeliefEvidenceNavigation {
  static const route = '/belief-evidence';
}

/// User-facing copy for the belief evidence trail.
abstract final class BeliefEvidenceTrailCopy {
  static const String title = VisibleArchiveProofCopy.beliefEvidenceTrailTitle;

  static const String notConclusion =
      VisibleArchiveProofCopy.beliefEvidenceNotConclusion;

  static const String sourceLine =
      VisibleArchiveProofCopy.beliefEvidenceSourceLine;

  static const String insufficientBody =
      VisibleArchiveProofCopy.beliefEvidenceInsufficientBody;

  static const String currentBeliefLabel =
      VisibleArchiveProofCopy.beliefEvidenceCurrentBeliefLabel;

  static const String whatChangedLabel =
      VisibleArchiveProofCopy.beliefEvidenceWhatChangedLabel;

  static const String evidenceLabel =
      VisibleArchiveProofCopy.beliefEvidenceArchiveLabel;

  static const String stillUncertainLabel =
      VisibleArchiveProofCopy.beliefEvidenceStillUncertainLabel;

  static const String evidenceStillThin =
      VisibleArchiveProofCopy.beliefEvidenceStillThin;

  static const String addNextLabel =
      VisibleArchiveProofCopy.beliefEvidenceAddNextLabel;

  static const String nextWhenThin =
      VisibleArchiveProofCopy.beliefEvidenceNextWhenThin;

  static const String nextDefault =
      VisibleArchiveProofCopy.beliefEvidenceNextDefault;

  static const String primaryCta =
      VisibleArchiveProofCopy.beliefUpdatePrimaryCta;
}

/// Proof trail content for a belief update — grounded in saved words only.
class BeliefEvidenceTrail {
  const BeliefEvidenceTrail({
    required this.hasEnoughEvidence,
    required this.title,
    this.notConclusionLine,
    this.sourceLine,
    this.currentBelief,
    this.whatChangedLine,
    this.evidenceRows = const [],
    this.sourceEntryIds = const [],
    this.uncertaintyLine,
    this.nextActionLine,
    this.primaryCta,
    this.insufficientBody,
    this.footnoteLine,
    this.historyTimeline,
    this.stageLabel,
  });

  factory BeliefEvidenceTrail.insufficient() {
    return const BeliefEvidenceTrail(
      hasEnoughEvidence: false,
      title: BeliefEvidenceTrailCopy.title,
      insufficientBody: BeliefEvidenceTrailCopy.insufficientBody,
    );
  }

  final bool hasEnoughEvidence;
  final String title;
  final String? notConclusionLine;
  final String? sourceLine;
  final String? currentBelief;
  final String? whatChangedLine;
  final List<String> evidenceRows;
  final List<String> sourceEntryIds;
  final String? uncertaintyLine;
  final String? nextActionLine;
  final String? primaryCta;
  final String? insufficientBody;
  final String? footnoteLine;
  final BeliefHistoryTimeline? historyTimeline;
  final String? stageLabel;
}

/// Builds the belief evidence trail from journal entries.
abstract final class BeliefEvidenceTrailEngine {
  BeliefEvidenceTrailEngine._();

  static BeliefEvidenceTrail build({
    required List<JournalEntry> entries,
    bool analysisSucceeded = true,
  }) {
    final payoff = BeliefUpdatePayoffEngine.build(
      entries: entries,
      analysisSucceeded: analysisSucceeded,
    );
    if (payoff == null) return BeliefEvidenceTrail.insufficient();

    final historyTimeline = BeliefHistoryTimelineEngine.build(entries: entries);

    return BeliefEvidenceTrail(
      hasEnoughEvidence: true,
      title: BeliefEvidenceTrailCopy.title,
      notConclusionLine: BeliefEvidenceTrailCopy.notConclusion,
      sourceLine: BeliefEvidenceTrailCopy.sourceLine,
      currentBelief: payoff.currentBelief,
      whatChangedLine: payoff.whatChangedLine,
      evidenceRows: payoff.evidenceRows,
      sourceEntryIds: payoff.sourceEntryIds,
      uncertaintyLine: payoff.evidenceWeak
          ? BeliefEvidenceTrailCopy.evidenceStillThin
          : null,
      nextActionLine: payoff.evidenceWeak
          ? BeliefEvidenceTrailCopy.nextWhenThin
          : BeliefEvidenceTrailCopy.nextDefault,
      primaryCta: BeliefEvidenceTrailCopy.primaryCta,
      footnoteLine: payoff.footnoteLine,
      historyTimeline: historyTimeline,
      stageLabel: payoff.stageLabel,
    );
  }
}
