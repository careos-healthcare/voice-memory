import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_copy.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:archiveme_mobile/features/insight_feedback/insight_feedback_store.dart';

/// Deterministic summaries from local feedback records.
class InsightFeedbackEngine {
  const InsightFeedbackEngine();

  InsightFeedbackSummary summaryFor({String? insightId}) {
    final records = insightId == null
        ? InsightFeedbackStore.cached
        : InsightFeedbackStore.cached
              .where((record) => record.insightId == insightId)
              .toList();

    if (records.isEmpty) return InsightFeedbackSummary.empty;

    final fitsCount = records
        .where((record) => record.choice == InsightFeedbackChoice.fits)
        .length;
    final notQuiteCount = records
        .where((record) => record.choice == InsightFeedbackChoice.notQuite)
        .length;
    final tooEarlyCount = records
        .where((record) => record.choice == InsightFeedbackChoice.tooEarly)
        .length;
    final saveAsWatchThemeCount = records
        .where(
          (record) => record.choice == InsightFeedbackChoice.saveAsWatchTheme,
        )
        .length;

    return InsightFeedbackSummary(
      latestRecord: records.first,
      fitsCount: fitsCount,
      notQuiteCount: notQuiteCount,
      tooEarlyCount: tooEarlyCount,
      saveAsWatchThemeCount: saveAsWatchThemeCount,
      trustSummaryLabel: InsightFeedbackCopy.trustSummaryLabel(
        fitsCount: fitsCount,
        notQuiteCount: notQuiteCount,
        tooEarlyCount: tooEarlyCount,
      ),
    );
  }

  bool hasAnyFeedback() => InsightFeedbackStore.cached.isNotEmpty;

  String betaOutcomesLabel() => hasAnyFeedback()
      ? InsightFeedbackCopy.betaOutcomesSome
      : InsightFeedbackCopy.betaOutcomesNone;
}