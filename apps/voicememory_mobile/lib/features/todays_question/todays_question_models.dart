import '../archive_clarity/archive_clarity_models.dart';

/// Deterministic question identifiers — no private journal content.
enum TodaysQuestionId {
  futureArchive,
  comparison,
  betaFeedback,
  watchTheme,
  reviewChange,
  rotated,
  adaptive,
}

/// How the Record screen should open capture for this question.
enum TodaysQuestionCaptureMode { voice, text, any }

/// Local inputs for today's one question — metadata only.
class TodaysQuestionInput {
  const TodaysQuestionInput({
    required this.realSavedMomentCount,
    required this.usableEvidenceCount,
    required this.hasWatchTheme,
    required this.betaFeedbackCaptured,
    this.archiveClarityStage = ArchiveClarityStageId.starting,
    this.weeklyReviewAvailable = false,
    this.sampleMode = false,
    this.dayKey = 0,
  });

  final int realSavedMomentCount;
  final int usableEvidenceCount;
  final bool hasWatchTheme;
  final bool betaFeedbackCaptured;
  final ArchiveClarityStageId archiveClarityStage;
  final bool weeklyReviewAvailable;
  final bool sampleMode;
  final int dayKey;
}

/// Local output for today's one question — no journal text.
class TodaysQuestionResult {
  const TodaysQuestionResult({
    required this.questionId,
    required this.eyebrow,
    required this.questionText,
    required this.helperText,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.suggestedCaptureMode,
    required this.isEmptyState,
    required this.isBetaFeedbackPrompt,
    required this.showOnRecord,
    this.secondaryCtaLabel,
    this.secondaryRoute,
  });

  final TodaysQuestionId questionId;
  final String eyebrow;
  final String questionText;
  final String helperText;
  final String primaryCtaLabel;
  final String primaryRoute;
  final TodaysQuestionCaptureMode suggestedCaptureMode;
  final bool isEmptyState;
  final bool isBetaFeedbackPrompt;
  final bool showOnRecord;
  final String? secondaryCtaLabel;
  final String? secondaryRoute;
}
