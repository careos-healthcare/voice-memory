import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';

/// Ladder stage for personalized next-moment prompts.
enum NextMomentPromptStage { one, two, three, four, fivePlus }

/// Navigation action for next-moment prompt CTAs.
enum NextMomentPromptAction {
  addMoment,
  viewEvidence,
  viewReview,
}

/// Tells users what kind of moment to capture next — evidence-based, not pressure.
class NextMomentPrompt {
  const NextMomentPrompt({
    required this.stage,
    required this.title,
    required this.body,
    required this.primaryCta,
    this.secondaryCta,
    required this.primaryAction,
    this.secondaryAction = NextMomentPromptAction.addMoment,
  });

  final NextMomentPromptStage stage;
  final String title;
  final String body;
  final String primaryCta;
  final String? secondaryCta;
  final NextMomentPromptAction primaryAction;
  final NextMomentPromptAction secondaryAction;

  /// Compact line for Archive Home "What to add next" section.
  String get nextActionSummary => title;
}

/// Builds next-moment prompts from eligible entry count — local only.
abstract final class NextMomentPromptEngine {
  NextMomentPromptEngine._();

  static NextMomentPrompt? build({
    required List<JournalEntry> entries,
  }) {
    final eligibleCount = ArchiveEvidenceGuard.eligibleReflectionCount(entries);
    if (eligibleCount == 0) return null;

    if (eligibleCount == 1) {
      return const NextMomentPrompt(
        stage: NextMomentPromptStage.one,
        title: VisibleArchiveProofCopy.nextMomentOneTitle,
        body: VisibleArchiveProofCopy.nextMomentOneBody,
        primaryCta: VisibleArchiveProofCopy.nextMomentAddCta,
        primaryAction: NextMomentPromptAction.addMoment,
      );
    }

    if (eligibleCount == 2) {
      return const NextMomentPrompt(
        stage: NextMomentPromptStage.two,
        title: VisibleArchiveProofCopy.nextMomentTwoTitle,
        body: VisibleArchiveProofCopy.nextMomentTwoBody,
        primaryCta: VisibleArchiveProofCopy.nextMomentAddCta,
        primaryAction: NextMomentPromptAction.addMoment,
      );
    }

    if (eligibleCount == 3) {
      return const NextMomentPrompt(
        stage: NextMomentPromptStage.three,
        title: VisibleArchiveProofCopy.nextMomentThreeTitle,
        body: VisibleArchiveProofCopy.nextMomentThreeBody,
        primaryCta: VisibleArchiveProofCopy.nextMomentAddCta,
        primaryAction: NextMomentPromptAction.addMoment,
      );
    }

    if (eligibleCount == 4) {
      return const NextMomentPrompt(
        stage: NextMomentPromptStage.four,
        title: VisibleArchiveProofCopy.nextMomentFourTitle,
        body: VisibleArchiveProofCopy.nextMomentFourBody,
        primaryCta: VisibleArchiveProofCopy.nextMomentAddCta,
        secondaryCta: VisibleArchiveProofCopy.nextMomentViewEvidenceCta,
        primaryAction: NextMomentPromptAction.addMoment,
        secondaryAction: NextMomentPromptAction.viewEvidence,
      );
    }

    return const NextMomentPrompt(
      stage: NextMomentPromptStage.fivePlus,
      title: VisibleArchiveProofCopy.nextMomentFivePlusTitle,
      body: VisibleArchiveProofCopy.nextMomentFivePlusBody,
      primaryCta: VisibleArchiveProofCopy.nextMomentAddCta,
      secondaryCta: VisibleArchiveProofCopy.nextMomentViewReviewCta,
      primaryAction: NextMomentPromptAction.addMoment,
      secondaryAction: NextMomentPromptAction.viewReview,
    );
  }
}
