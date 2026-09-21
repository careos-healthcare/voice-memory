import 'package:archiveme_mobile/features/activation/context_aware_archive_copy.dart';
import 'package:archiveme_mobile/features/activation/correction_informed_next_prompt.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_ui/models/next_moment_prompt.dart';

export 'package:archiveme_ui/models/next_moment_prompt.dart';

/// Builds next-moment prompts from eligible entry count — local only.
abstract final class NextMomentPromptEngine {
  NextMomentPromptEngine._();

  static NextMomentPrompt? build({required List<JournalEntry> entries}) {
    final eligibleCount = ArchiveEvidenceGuard.eligibleReflectionCount(entries);
    if (eligibleCount == 0) return null;

    final base = _buildBase(eligibleCount, entries);
    return CorrectionInformedNextPrompt.apply(
      base: base,
      eligibleCount: eligibleCount,
    );
  }

  static NextMomentPrompt _buildBase(
    int eligibleCount,
    List<JournalEntry> entries,
  ) {
    final base = _baseForCount(eligibleCount);
    return _withContextAware(base, entries);
  }

  static NextMomentPrompt _baseForCount(int eligibleCount) {
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

  static NextMomentPrompt _withContextAware(
    NextMomentPrompt base,
    List<JournalEntry> entries,
  ) {
    final contextCopy = ContextAwareArchiveCopyEngine.build(entries: entries);
    if (!contextCopy.showLines) return base;

    final parts = <String>[base.body];
    if (contextCopy.summaryLine case final summary?) {
      parts.add(summary);
    }
    if (contextCopy.detailLine case final detail?) {
      parts.add(detail);
    }

    return NextMomentPrompt(
      stage: base.stage,
      title: base.title,
      body: parts.join(' '),
      primaryCta: base.primaryCta,
      secondaryCta: base.secondaryCta,
      primaryAction: base.primaryAction,
      secondaryAction: base.secondaryAction,
    );
  }
}
