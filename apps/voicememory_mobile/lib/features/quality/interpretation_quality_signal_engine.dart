import '../post_save_insight/post_save_insight_models.dart';
import '../post_save_insight/signal_feedback_model.dart';
import 'interpretation_quality_signal_model.dart';

/// Scores whether post-save reads are useful — internal only.
class InterpretationQualitySignalEngine {
  const InterpretationQualitySignalEngine();

  ReadSpecificityLevel specificityFor(PostSaveInsightSignal signal) {
    final chips = signal.evidenceChips.length;
    final titleLen = signal.title.trim().length;
    if (chips >= 2 && titleLen >= 18) return ReadSpecificityLevel.high;
    if (chips >= 1 || titleLen >= 12) return ReadSpecificityLevel.medium;
    return ReadSpecificityLevel.low;
  }

  ReadSourceKind sourceFor({
    required PostSaveInsightBundle bundle,
    required PostSaveInsightSignal signal,
  }) {
    if (bundle.archiveRepeatDetected) return ReadSourceKind.archiveRepeat;
    if (bundle.changedAngleDetected) return ReadSourceKind.feedbackAdjusted;
    if (!signal.isPrimary) return ReadSourceKind.feedbackAdjusted;
    return ReadSourceKind.latestOnly;
  }

  ReadUserAction actionFromFeedback(PostSaveSignalAction action) {
    switch (action) {
      case PostSaveSignalAction.accepted:
        return ReadUserAction.accepted;
      case PostSaveSignalAction.rejected:
        return ReadUserAction.rejected;
      case PostSaveSignalAction.deeperOpened:
        return ReadUserAction.deeperOpened;
      case PostSaveSignalAction.anotherAngleShown:
      case PostSaveSignalAction.abChoiceNeither:
        return ReadUserAction.alternativeChosen;
      default:
        return ReadUserAction.ignored;
    }
  }

  InterpretationQualityLabel diagnoseQuality({
    required ReadUserAction action,
    required List<InterpretationQualitySignal> sessionSignals,
  }) {
    if (action == ReadUserAction.accepted ||
        action == ReadUserAction.deeperOpened) {
      return InterpretationQualityLabel.strong;
    }
    if (action == ReadUserAction.rejected ||
        action == ReadUserAction.alternativeChosen) {
      final rejectedAll = sessionSignals.isNotEmpty &&
          sessionSignals.every(
            (s) =>
                s.userAction == ReadUserAction.rejected ||
                s.userAction == ReadUserAction.alternativeChosen,
          );
      if (rejectedAll && sessionSignals.length >= 2) {
        return InterpretationQualityLabel.weak;
      }
      return InterpretationQualityLabel.unclear;
    }
    return InterpretationQualityLabel.unclear;
  }

  InterpretationQualitySignal buildSignal({
    required PostSaveInsightSignal read,
    required PostSaveInsightBundle bundle,
    required ReadUserAction action,
    DateTime? shownAt,
    DateTime? actedAt,
    bool nextPromptUsed = false,
    List<InterpretationQualitySignal> priorSession = const [],
  }) {
    final created = shownAt ?? DateTime.now();
    int? seconds;
    if (shownAt != null && actedAt != null) {
      seconds = actedAt.difference(shownAt).inSeconds.clamp(0, 9999);
    }
    final label = diagnoseQuality(
      action: action,
      sessionSignals: [
        ...priorSession,
        InterpretationQualitySignal(
          readId: read.readId ?? read.id,
          readTitle: read.title,
          specificityLevel: specificityFor(read),
          strengthLabel: read.strengthLabel,
          evidenceCount: read.evidenceChips.length,
          userAction: action,
          createdAt: created,
          source: sourceFor(bundle: bundle, signal: read),
          nextPromptUsed: nextPromptUsed,
        ),
      ],
    );
    return InterpretationQualitySignal(
      readId: read.readId ?? read.id,
      readTitle: read.title,
      specificityLevel: specificityFor(read),
      strengthLabel: read.strengthLabel,
      evidenceCount: read.evidenceChips.length,
      userAction: action,
      timeToActionSeconds: seconds,
      createdAt: created,
      source: sourceFor(bundle: bundle, signal: read),
      nextPromptUsed: nextPromptUsed,
      qualityLabel: label,
    );
  }
}
