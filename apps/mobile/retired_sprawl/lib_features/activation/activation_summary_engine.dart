import 'package:archiveme_mobile/features/activation/activation_summary_model.dart';
import 'package:archiveme_mobile/features/activation/first_pattern_correction_store.dart';
import 'package:archiveme_mobile/features/activation/return_capture_metrics_store.dart';
import 'package:archiveme_mobile/features/activation/watch_for_prompt_metrics_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Builds activation summaries from locally stored events.
class ActivationSummaryEngine {
  const ActivationSummaryEngine();

  static const int weakQualityCorrectionThreshold = 2;

  Future<ActivationSummary> build() async {
    final prefs = AppServices.instance.prefs;
    final correctionStore = FirstPatternCorrectionStore(prefs);
    final watchMetrics = WatchForPromptMetricsStore(prefs);
    final returnCaptureMetrics = ReturnCaptureMetricsStore(prefs);
    final count = await correctionStore.correctionCount();
    final watch = await watchMetrics.read();
    final capture = await returnCaptureMetrics.read();
    return ActivationSummary(
      firstPatternCorrectionCount: count,
      firstPatternQualityWeak: count >= weakQualityCorrectionThreshold,
      watchForPromptShownCount: watch.shownCount,
      watchForPromptAcceptedCount: watch.acceptedCount,
      watchForPromptAcceptanceRate: watch.acceptanceRate,
      returnCaptureQuickAnswerSelectedCount: capture.quickAnswerSelectedCount,
      returnCaptureRecordedAfterSelectionCount:
          capture.recordedAfterQuickAnswerCount,
      returnCaptureSkippedCount: capture.skippedCount,
      returnCaptureQuickAnswerSelectionRate: capture.quickAnswerSelectionRate,
      returnCaptureRecordedAfterQuickAnswerRate:
          capture.recordedAfterQuickAnswerRate,
    );
  }
}