import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback_adaptation.dart';
import 'package:archiveme_mobile/features/activation/next_moment_prompt.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';

/// Which visible insight target is driving a correction-aware next prompt.
enum CorrectionInformedPromptTarget { weeklyReview, belief, archiveHome }

/// Resolved local correction context for next-moment prompts.
class CorrectionInformedNextPromptContext {
  const CorrectionInformedNextPromptContext({
    required this.target,
    required this.insightId,
  });

  final CorrectionInformedPromptTarget target;
  final String insightId;
}

/// Applies local correction note context to next-moment prompts — never shared.
abstract final class CorrectionInformedNextPrompt {
  CorrectionInformedNextPrompt._();

  static CorrectionInformedNextPromptContext? activeContext({
    required int eligibleCount,
  }) {
    for (final candidate in _candidateTargets(eligibleCount)) {
      final insightId = ArchiveInsightFeedbackAdaptation.resolveInsightId(
        candidate.feedbackTarget,
        archiveHomeStage: candidate.archiveHomeStage,
      );
      if (ArchiveInsightFeedbackStore.isHidden(insightId)) continue;
      if (!ArchiveInsightFeedbackStore.hasCorrectionNote(insightId)) continue;
      return CorrectionInformedNextPromptContext(
        target: candidate.promptTarget,
        insightId: insightId,
      );
    }
    return null;
  }

  static NextMomentPrompt apply({
    required NextMomentPrompt base,
    required int eligibleCount,
  }) {
    final context = activeContext(eligibleCount: eligibleCount);
    if (context == null) return base;

    final copy = _copyFor(context: context, eligibleCount: eligibleCount);
    final secondary = _secondaryFor(
      context: context,
      eligibleCount: eligibleCount,
    );

    return NextMomentPrompt(
      stage: base.stage,
      title: copy.title,
      body: copy.body,
      primaryCta: VisibleArchiveProofCopy.nextMomentAddCta,
      secondaryCta: secondary?.cta,
      primaryAction: NextMomentPromptAction.addMoment,
      secondaryAction: secondary?.action ?? NextMomentPromptAction.addMoment,
    );
  }

  static _CandidateTarget _candidate({
    required ArchiveInsightTarget feedbackTarget,
    required CorrectionInformedPromptTarget promptTarget,
    ArchiveHomeStage? archiveHomeStage,
  }) => _CandidateTarget(
    feedbackTarget: feedbackTarget,
    promptTarget: promptTarget,
    archiveHomeStage: archiveHomeStage,
  );

  static List<_CandidateTarget> _candidateTargets(int eligibleCount) {
    final candidates = <_CandidateTarget>[];
    if (eligibleCount >= 5) {
      candidates.add(
        _candidate(
          feedbackTarget: ArchiveInsightTarget.weeklyReview,
          promptTarget: CorrectionInformedPromptTarget.weeklyReview,
        ),
      );
    }
    if (eligibleCount >= 4) {
      candidates.addAll([
        _candidate(
          feedbackTarget: ArchiveInsightTarget.beliefUpdate,
          promptTarget: CorrectionInformedPromptTarget.belief,
        ),
        _candidate(
          feedbackTarget: ArchiveInsightTarget.beliefEvidence,
          promptTarget: CorrectionInformedPromptTarget.belief,
        ),
        _candidate(
          feedbackTarget: ArchiveInsightTarget.archiveHome,
          promptTarget: CorrectionInformedPromptTarget.belief,
          archiveHomeStage: ArchiveHomeStage.four,
        ),
      ]);
    }
    if (eligibleCount >= 5) {
      candidates.add(
        _candidate(
          feedbackTarget: ArchiveInsightTarget.archiveHome,
          promptTarget: CorrectionInformedPromptTarget.archiveHome,
          archiveHomeStage: ArchiveHomeStage.fivePlus,
        ),
      );
    }
    if (eligibleCount >= 3) {
      candidates.add(
        _candidate(
          feedbackTarget: ArchiveInsightTarget.archiveHome,
          promptTarget: CorrectionInformedPromptTarget.archiveHome,
          archiveHomeStage: ArchiveHomeStage.three,
        ),
      );
    }
    return candidates;
  }

  static _CorrectionCopy _copyFor({
    required CorrectionInformedNextPromptContext context,
    required int eligibleCount,
  }) {
    if (context.target == CorrectionInformedPromptTarget.weeklyReview &&
        eligibleCount >= 5) {
      return const _CorrectionCopy(
        title: VisibleArchiveProofCopy.correctionNextFiveReviewTitle,
        body: VisibleArchiveProofCopy.correctionNextFiveReviewBody,
      );
    }

    if (context.target == CorrectionInformedPromptTarget.belief &&
        eligibleCount >= 4) {
      return const _CorrectionCopy(
        title: VisibleArchiveProofCopy.correctionNextFourTitle,
        body: VisibleArchiveProofCopy.correctionNextFourBody,
      );
    }

    var body = VisibleArchiveProofCopy.correctionNextGenericBody;
    if (eligibleCount < 4) {
      body =
          '$body ${VisibleArchiveProofCopy.correctionNextThinEvidenceSuffix}';
    }

    return _CorrectionCopy(
      title: VisibleArchiveProofCopy.correctionNextGenericTitle,
      body: body,
    );
  }

  static _SecondaryCta? _secondaryFor({
    required CorrectionInformedNextPromptContext context,
    required int eligibleCount,
  }) {
    if (context.target == CorrectionInformedPromptTarget.weeklyReview &&
        eligibleCount >= 5) {
      return const _SecondaryCta(
        cta: VisibleArchiveProofCopy.nextMomentViewReviewCta,
        action: NextMomentPromptAction.viewReview,
      );
    }
    if (eligibleCount >= 4) {
      return const _SecondaryCta(
        cta: VisibleArchiveProofCopy.nextMomentViewEvidenceCta,
        action: NextMomentPromptAction.viewEvidence,
      );
    }
    return null;
  }
}

class _CandidateTarget {
  const _CandidateTarget({
    required this.feedbackTarget,
    required this.promptTarget,
    this.archiveHomeStage,
  });

  final ArchiveInsightTarget feedbackTarget;
  final CorrectionInformedPromptTarget promptTarget;
  final ArchiveHomeStage? archiveHomeStage;
}

class _CorrectionCopy {
  const _CorrectionCopy({required this.title, required this.body});

  final String title;
  final String body;
}

class _SecondaryCta {
  const _SecondaryCta({required this.cta, required this.action});

  final String cta;
  final NextMomentPromptAction action;
}