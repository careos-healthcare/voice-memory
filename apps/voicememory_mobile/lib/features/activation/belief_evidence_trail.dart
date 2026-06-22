import '../../models/journal_entry.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import 'belief_history_timeline.dart';
import 'belief_update_payoff.dart';

/// Route for the belief evidence drilldown screen.
abstract final class BeliefEvidenceNavigation {
  static const route = '/belief-evidence';
}

/// User-facing copy for the belief evidence trail.
abstract final class BeliefEvidenceTrailCopy {
  static const title = VisibleArchiveProofCopy.beliefEvidenceTrailTitle;

  static const notConclusion = VisibleArchiveProofCopy.beliefEvidenceNotConclusion;

  static const sourceLine = VisibleArchiveProofCopy.beliefEvidenceSourceLine;

  static const insufficientBody =
      VisibleArchiveProofCopy.beliefEvidenceInsufficientBody;

  static const currentBeliefLabel =
      VisibleArchiveProofCopy.beliefEvidenceCurrentBeliefLabel;

  static const whatChangedLabel =
      VisibleArchiveProofCopy.beliefEvidenceWhatChangedLabel;

  static const evidenceLabel =
      VisibleArchiveProofCopy.beliefEvidenceArchiveLabel;

  static const stillUncertainLabel =
      VisibleArchiveProofCopy.beliefEvidenceStillUncertainLabel;

  static const evidenceStillThin =
      VisibleArchiveProofCopy.beliefEvidenceStillThin;

  static const addNextLabel = VisibleArchiveProofCopy.beliefEvidenceAddNextLabel;

  static const nextWhenThin = VisibleArchiveProofCopy.beliefEvidenceNextWhenThin;

  static const nextDefault = VisibleArchiveProofCopy.beliefEvidenceNextDefault;

  static const primaryCta = VisibleArchiveProofCopy.beliefUpdatePrimaryCta;
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
    this.uncertaintyLine,
    this.nextActionLine,
    this.primaryCta,
    this.insufficientBody,
    this.footnoteLine,
    this.historyTimeline,
  });

  final bool hasEnoughEvidence;
  final String title;
  final String? notConclusionLine;
  final String? sourceLine;
  final String? currentBelief;
  final String? whatChangedLine;
  final List<String> evidenceRows;
  final String? uncertaintyLine;
  final String? nextActionLine;
  final String? primaryCta;
  final String? insufficientBody;
  final String? footnoteLine;
  final BeliefHistoryTimeline? historyTimeline;

  factory BeliefEvidenceTrail.insufficient() {
    return const BeliefEvidenceTrail(
      hasEnoughEvidence: false,
      title: BeliefEvidenceTrailCopy.title,
      insufficientBody: BeliefEvidenceTrailCopy.insufficientBody,
    );
  }
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
      uncertaintyLine:
          payoff.evidenceWeak ? BeliefEvidenceTrailCopy.evidenceStillThin : null,
      nextActionLine: payoff.evidenceWeak
          ? BeliefEvidenceTrailCopy.nextWhenThin
          : BeliefEvidenceTrailCopy.nextDefault,
      primaryCta: BeliefEvidenceTrailCopy.primaryCta,
      footnoteLine: payoff.footnoteLine,
      historyTimeline: historyTimeline,
    );
  }
}
