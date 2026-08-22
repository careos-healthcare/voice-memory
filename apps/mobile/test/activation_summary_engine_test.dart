import 'package:archiveme_mobile/features/activation/activation_summary_engine.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/activation/first_pattern_correction_store.dart';
import 'package:archiveme_mobile/features/activation/return_capture_metrics_store.dart';
import 'package:archiveme_mobile/features/activation/watch_for_prompt_metrics_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_activation_journal_$stamp.json',
    prefsPath: '/tmp/vm_activation_prefs_$stamp.json',
  );
}

void main() {
  test('activation summary counts first-pattern corrections', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final store = FirstPatternCorrectionStore(AppServices.instance.prefs);
    expect(await store.correctionCount(), 0);

    await ActivationTracker.trackFirstPatternCorrected(
      originalTitle: 'Taking responsibility before asking for help',
      selectedTitle: 'The same worry returning',
      confidenceScore: 0.55,
    );
    await ActivationTracker.trackFirstPatternCorrected(
      originalTitle: 'Taking responsibility before asking for help',
      selectedTitle: 'Something worth watching',
      confidenceScore: 0.55,
    );

    final summary = await const ActivationSummaryEngine().build();
    expect(summary.firstPatternCorrectionCount, 2);
    expect(summary.firstPatternQualityWeak, isTrue);
  });

  test('single correction is not weak quality yet', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await ActivationTracker.trackFirstPatternCorrected(
      originalTitle: 'A',
      selectedTitle: 'B',
      confidenceScore: 0.4,
    );

    final summary = await const ActivationSummaryEngine().build();
    expect(summary.firstPatternCorrectionCount, 1);
    expect(summary.firstPatternQualityWeak, isFalse);
  });

  test('activation summary includes return capture metrics', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final captureStore = ReturnCaptureMetricsStore(AppServices.instance.prefs);
    await captureStore.recordQuickAnswerSelected();
    await captureStore.recordQuickAnswerSelected();
    await captureStore.recordRecordedAfterQuickAnswer();
    await captureStore.recordSkipped();

    final summary = await const ActivationSummaryEngine().build();
    expect(summary.returnCaptureQuickAnswerSelectedCount, 2);
    expect(summary.returnCaptureRecordedAfterSelectionCount, 1);
    expect(summary.returnCaptureSkippedCount, 1);
    expect(summary.returnCaptureQuickAnswerSelectionRate, closeTo(2 / 3, 0.01));
    expect(summary.returnCaptureRecordedAfterQuickAnswerRate, 0.5);
  });

  test('activation summary includes watch-for prompt metrics', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await ActivationTracker.trackWatchForPromptShown(strength: 'high');
    await ActivationTracker.trackWatchForPromptShown(strength: 'medium');
    await ActivationTracker.trackWatchForPromptAccepted(strength: 'high');

    final summary = await const ActivationSummaryEngine().build();
    expect(summary.watchForPromptShownCount, 2);
    expect(summary.watchForPromptAcceptedCount, 1);
    expect(summary.watchForPromptAcceptanceRate, 0.5);

    final metrics = WatchForPromptMetricsStore(AppServices.instance.prefs);
    final raw = await metrics.read();
    expect(raw.highStrengthAccepted, 1);
  });
}