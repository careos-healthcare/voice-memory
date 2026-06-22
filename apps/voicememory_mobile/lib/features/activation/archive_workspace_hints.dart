import '../archive_proof/visible_archive_proof_copy.dart';
import 'archive_workspace_hint_store.dart';
import 'archive_workspace_layout.dart';

/// Stable ids for Archive workspace onboarding hints.
abstract final class ArchiveWorkspaceHintIds {
  ArchiveWorkspaceHintIds._();

  static const intro = 'intro';
  static const needsAttention = 'needs_attention';
  static const evidenceQuality = 'evidence_quality';
  static const reviewHistory = 'review_history';
}

/// One dismissible Archive workspace hint.
class ArchiveWorkspaceHint {
  const ArchiveWorkspaceHint({
    required this.hintId,
    required this.body,
    this.title,
    this.compact = false,
  });

  final String hintId;
  final String? title;
  final String body;
  final bool compact;

  bool get isIntro => hintId == ArchiveWorkspaceHintIds.intro;
}

/// Which hints to show in the current workspace state.
class ArchiveWorkspaceHintsPlan {
  const ArchiveWorkspaceHintsPlan({
    this.introHint,
    this.needsAttentionHint,
    this.evidenceQualityHint,
    this.reviewHistoryHint,
  });

  final ArchiveWorkspaceHint? introHint;
  final ArchiveWorkspaceHint? needsAttentionHint;
  final ArchiveWorkspaceHint? evidenceQualityHint;
  final ArchiveWorkspaceHint? reviewHistoryHint;

  bool get hasIntroHint => introHint != null;

  Iterable<ArchiveWorkspaceHint> get sectionHints sync* {
    if (needsAttentionHint case final hint?) yield hint;
    if (evidenceQualityHint case final hint?) yield hint;
    if (reviewHistoryHint case final hint?) yield hint;
  }

  bool get isEmpty =>
      introHint == null &&
      needsAttentionHint == null &&
      evidenceQualityHint == null &&
      reviewHistoryHint == null;
}

/// Builds deterministic workspace hints from layout and dismissal state.
abstract final class ArchiveWorkspaceHintsEngine {
  ArchiveWorkspaceHintsEngine._();

  static ArchiveWorkspaceHintsPlan build({
    required ArchiveWorkspaceLayout layout,
  }) {
    final introHint = _introHint();

    return ArchiveWorkspaceHintsPlan(
      introHint: introHint,
      needsAttentionHint: layout.showAttentionFilters
          ? _sectionHint(
              hintId: ArchiveWorkspaceHintIds.needsAttention,
              body: VisibleArchiveProofCopy.archiveWorkspaceHintNeedsAttentionBody,
            )
          : null,
      evidenceQualityHint:
          layout.evidenceQuality.show && layout.eligibleCount >= 3
              ? _sectionHint(
                  hintId: ArchiveWorkspaceHintIds.evidenceQuality,
                  body: VisibleArchiveProofCopy
                      .archiveWorkspaceHintEvidenceQualityBody,
                )
              : null,
      reviewHistoryHint: layout.reviewHistory.show && layout.eligibleCount >= 5
          ? _sectionHint(
              hintId: ArchiveWorkspaceHintIds.reviewHistory,
              body: VisibleArchiveProofCopy.archiveWorkspaceHintReviewHistoryBody,
            )
          : null,
    );
  }

  static ArchiveWorkspaceHint? _introHint() {
    if (ArchiveWorkspaceHintStore.isDismissed(ArchiveWorkspaceHintIds.intro)) {
      return null;
    }
    return const ArchiveWorkspaceHint(
      hintId: ArchiveWorkspaceHintIds.intro,
      title: VisibleArchiveProofCopy.archiveWorkspaceHintIntroTitle,
      body: VisibleArchiveProofCopy.archiveWorkspaceHintIntroBody,
    );
  }

  static ArchiveWorkspaceHint? _sectionHint({
    required String hintId,
    required String body,
  }) {
    if (ArchiveWorkspaceHintStore.isDismissed(hintId)) return null;
    return ArchiveWorkspaceHint(
      hintId: hintId,
      body: body,
      compact: true,
    );
  }
}
