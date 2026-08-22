import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Ladder stage for the returning-user Today card on Record.
enum ReturningUserTodayStage { one, two, three, four, fivePlus }

/// Primary navigation action for Today card CTAs.
enum ReturningUserTodayAction {
  addMoment,
  viewArchive,
  viewEvidence,
  viewReview,
}

/// Compact return guidance for users reopening Record with saved entries.
class ReturningUserToday {
  const ReturningUserToday({
    required this.stage,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final ReturningUserTodayStage stage;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final ReturningUserTodayAction primaryAction;
  final ReturningUserTodayAction secondaryAction;
}

/// Builds Today card copy from eligible entry count — local only, no analysis gate.
abstract final class ReturningUserTodayEngine {
  ReturningUserTodayEngine._();

  static ReturningUserToday? build({required List<JournalEntry> entries}) {
    final eligibleCount = ArchiveEvidenceGuard.eligibleReflectionCount(entries);
    if (eligibleCount == 0) return null;

    if (eligibleCount == 1) {
      return const ReturningUserToday(
        stage: ReturningUserTodayStage.one,
        title: VisibleArchiveProofCopy.returningUserOneTitle,
        body: VisibleArchiveProofCopy.returningUserOneBody,
        primaryCta: VisibleArchiveProofCopy.returningUserAddMomentCta,
        secondaryCta: VisibleArchiveProofCopy.returningUserViewArchiveCta,
        primaryAction: ReturningUserTodayAction.addMoment,
        secondaryAction: ReturningUserTodayAction.viewArchive,
      );
    }

    if (eligibleCount == 2) {
      return const ReturningUserToday(
        stage: ReturningUserTodayStage.two,
        title: VisibleArchiveProofCopy.returningUserTwoTitle,
        body: VisibleArchiveProofCopy.returningUserTwoBody,
        primaryCta: VisibleArchiveProofCopy.returningUserAddMomentCta,
        secondaryCta: VisibleArchiveProofCopy.returningUserViewArchiveCta,
        primaryAction: ReturningUserTodayAction.addMoment,
        secondaryAction: ReturningUserTodayAction.viewArchive,
      );
    }

    if (eligibleCount == 3) {
      return const ReturningUserToday(
        stage: ReturningUserTodayStage.three,
        title: VisibleArchiveProofCopy.returningUserThreeTitle,
        body: VisibleArchiveProofCopy.returningUserThreeBody,
        primaryCta: VisibleArchiveProofCopy.returningUserAddMomentCta,
        secondaryCta: VisibleArchiveProofCopy.returningUserViewArchiveCta,
        primaryAction: ReturningUserTodayAction.addMoment,
        secondaryAction: ReturningUserTodayAction.viewArchive,
      );
    }

    if (eligibleCount == 4) {
      return const ReturningUserToday(
        stage: ReturningUserTodayStage.four,
        title: VisibleArchiveProofCopy.returningUserFourTitle,
        body: VisibleArchiveProofCopy.returningUserFourBody,
        primaryCta: VisibleArchiveProofCopy.returningUserAddMomentCta,
        secondaryCta: VisibleArchiveProofCopy.returningUserViewEvidenceCta,
        primaryAction: ReturningUserTodayAction.addMoment,
        secondaryAction: ReturningUserTodayAction.viewEvidence,
      );
    }

    return const ReturningUserToday(
      stage: ReturningUserTodayStage.fivePlus,
      title: VisibleArchiveProofCopy.returningUserFivePlusTitle,
      body: VisibleArchiveProofCopy.returningUserFivePlusBody,
      primaryCta: VisibleArchiveProofCopy.returningUserViewReviewCta,
      secondaryCta: VisibleArchiveProofCopy.returningUserAddMomentCta,
      primaryAction: ReturningUserTodayAction.viewReview,
      secondaryAction: ReturningUserTodayAction.addMoment,
    );
  }
}