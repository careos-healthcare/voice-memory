import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/tomorrow_return/change_summary_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/change_summary_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_comparison_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';

ReturnComparison _comparison(ReturnComparisonStatus status) {
  return ReturnComparison(
    yesterdayWatchFor: 'taking responsibility before asking for help',
    todayReflectionSummary: 'Said yes too quickly again today.',
    comparisonStatus: status,
    headline: 'headline',
    body: 'body',
    chips: const ['showed up again', 'saying yes too fast'],
    createdAt: DateTime(2026, 6, 3),
  );
}

void main() {
  test('change summary repeated maps to steady or stronger', () {
    const engine = ChangeSummaryEngine();
    final summary = engine.build(
      latest: _comparison(ReturnComparisonStatus.repeated),
      recent: [
        _comparison(ReturnComparisonStatus.repeated),
        _comparison(ReturnComparisonStatus.repeated),
      ],
    );
    expect(
      summary.status,
      anyOf(
        ChangeSummaryStatus.steady,
        ChangeSummaryStatus.stronger,
      ),
    );
    expect(summary.title, isNotEmpty);
    expect(summary.chips, isNotEmpty);
  });

  test('change summary shifted status', () {
    const engine = ChangeSummaryEngine();
    final summary = engine.build(
      latest: _comparison(ReturnComparisonStatus.shifted),
    );
    expect(summary.status, ChangeSummaryStatus.shifted);
    expect(summary.title, ConsumerUiCopy.changeSummaryTitleShifted);
  });

  test('change summary eased status', () {
    const engine = ChangeSummaryEngine();
    final summary = engine.build(
      latest: _comparison(ReturnComparisonStatus.eased),
    );
    expect(summary.status, ChangeSummaryStatus.softer);
    expect(summary.title, ConsumerUiCopy.changeSummaryTitleSofter);
  });

  test('change summary unclear status', () {
    const engine = ChangeSummaryEngine();
    final summary = engine.build(
      latest: _comparison(ReturnComparisonStatus.unclear),
    );
    expect(summary.status, ChangeSummaryStatus.unclear);
  });

  test('screenshot sample change summary', () {
    final sample = ScreenshotSampleData.changeSummarySample;
    expect(sample.title, ConsumerUiCopy.changeSummaryTitleSteady);
    expect(sample.summary, contains('steady'));
  });
}
