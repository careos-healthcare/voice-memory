import '../../product/consumer_ui_copy.dart';
import 'change_summary_model.dart';
import 'return_comparison_model.dart';

class ChangeSummaryEngine {
  const ChangeSummaryEngine();

  ChangeSummary build({
    required ReturnComparison latest,
    List<ReturnComparison> recent = const [],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final status = _status(latest, recent);
    final watch = latest.yesterdayWatchFor.trim();
    final title = _title(status);
    final summary = _summary(
      status: status,
      watch: watch,
      latest: latest,
      recent: recent,
    );
    final chips = _chips(status, latest, recent);

    return ChangeSummary(
      title: title,
      summary: summary,
      status: status,
      chips: chips,
      createdAt: clock,
    );
  }

  ChangeSummaryStatus _status(
    ReturnComparison latest,
    List<ReturnComparison> recent,
  ) {
    switch (latest.comparisonStatus) {
      case ReturnComparisonStatus.repeated:
        final repeats = recent
            .where((c) => c.comparisonStatus == ReturnComparisonStatus.repeated)
            .length;
        return repeats >= 2
            ? ChangeSummaryStatus.stronger
            : ChangeSummaryStatus.steady;
      case ReturnComparisonStatus.eased:
        return ChangeSummaryStatus.softer;
      case ReturnComparisonStatus.shifted:
        return ChangeSummaryStatus.shifted;
      case ReturnComparisonStatus.absent:
        return ChangeSummaryStatus.steady;
      case ReturnComparisonStatus.unclear:
        return ChangeSummaryStatus.unclear;
    }
  }

  String _title(ChangeSummaryStatus status) {
    switch (status) {
      case ChangeSummaryStatus.stronger:
        return ConsumerUiCopy.changeSummaryTitleStronger;
      case ChangeSummaryStatus.softer:
        return ConsumerUiCopy.changeSummaryTitleSofter;
      case ChangeSummaryStatus.shifted:
        return ConsumerUiCopy.changeSummaryTitleShifted;
      case ChangeSummaryStatus.steady:
        return ConsumerUiCopy.changeSummaryTitleSteady;
      case ChangeSummaryStatus.unclear:
        return ConsumerUiCopy.changeSummaryTitleUnclear;
    }
  }

  String _summary({
    required ChangeSummaryStatus status,
    required String watch,
    required ReturnComparison latest,
    required List<ReturnComparison> recent,
  }) {
    final focus = watch.isNotEmpty ? watch : 'what you were watching for';
    switch (status) {
      case ChangeSummaryStatus.stronger:
        return '$focus showed up again today. It may be getting stronger across your recent moments.';
      case ChangeSummaryStatus.softer:
        return '$focus came up again, but today sounded a little lighter than before.';
      case ChangeSummaryStatus.shifted:
        return '$focus changed shape today — related, but not quite the same as yesterday.';
      case ChangeSummaryStatus.steady:
        if (latest.comparisonStatus == ReturnComparisonStatus.absent) {
          return '$focus was not there today. The pattern may be steady elsewhere for now.';
        }
        return '$focus showed up again today. It looks steady, not resolved yet.';
      case ChangeSummaryStatus.unclear:
        return ConsumerUiCopy.changeSummarySummaryUnclear;
    }
  }

  List<String> _chips(
    ChangeSummaryStatus status,
    ReturnComparison latest,
    List<ReturnComparison> recent,
  ) {
    final chips = <String>[...latest.chips, ...recent.expand((c) => c.chips)];
    final unique = <String>[];
    for (final c in chips) {
      final t = c.trim();
      if (t.isNotEmpty && !unique.contains(t)) unique.add(t);
    }

    switch (status) {
      case ChangeSummaryStatus.stronger:
        return [
          ConsumerUiCopy.changeSummaryChipGotStronger,
          if (unique.isNotEmpty) unique.first,
          ConsumerUiCopy.changeSummaryChipWatchTomorrow,
        ].take(3).toList();
      case ChangeSummaryStatus.softer:
        return [
          ConsumerUiCopy.changeSummaryChipEased,
          if (unique.isNotEmpty) unique.first,
          ConsumerUiCopy.changeSummaryChipWatchTomorrow,
        ].take(3).toList();
      case ChangeSummaryStatus.shifted:
        return [
          ConsumerUiCopy.changeSummaryChipChangedShape,
          if (unique.length > 1)
            unique[1]
          else if (unique.isNotEmpty)
            unique.first,
          ConsumerUiCopy.changeSummaryChipWatchTomorrow,
        ].take(3).toList();
      case ChangeSummaryStatus.steady:
        return [
          ConsumerUiCopy.returnComparisonChipShowedAgain,
          ConsumerUiCopy.changeSummaryChipSamePressure,
          ConsumerUiCopy.changeSummaryChipWatchTomorrow,
        ];
      case ChangeSummaryStatus.unclear:
        return [ConsumerUiCopy.changeSummaryChipNeedAnotherMoment];
    }
  }
}
