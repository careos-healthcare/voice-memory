import '../../product/consumer_ui_copy.dart';
import 'return_comparison_model.dart';
import 'return_streak_model.dart';

class WeeklyPatternRecap {
  const WeeklyPatternRecap({
    required this.title,
    required this.body,
    required this.chips,
  });

  final String title;
  final String body;
  final List<String> chips;
}

class WeeklyPatternRecapEngine {
  const WeeklyPatternRecapEngine();

  static const int minDataPoints = 3;

  WeeklyPatternRecap? build({
    ReturnStreak? streak,
    List<ReturnComparison> comparisons = const [],
  }) {
    final completedCount = streak?.completedDates.length ?? 0;
    final comparisonCount = comparisons.length;
    if (completedCount < minDataPoints && comparisonCount < minDataPoints) {
      return null;
    }

    final chips = _topChips(comparisons);
    final theme = _dominantTheme(comparisons, chips);
    final body = _body(theme, chips, completedCount, comparisonCount);

    return WeeklyPatternRecap(
      title: ConsumerUiCopy.weeklyRecapTitle,
      body: body,
      chips: chips.take(3).toList(),
    );
  }

  List<String> _topChips(List<ReturnComparison> comparisons) {
    final counts = <String, int>{};
    for (final c in comparisons) {
      for (final chip in c.chips) {
        final t = chip.trim().toLowerCase();
        if (t.isEmpty) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  String _dominantTheme(
    List<ReturnComparison> comparisons,
    List<String> chips,
  ) {
    if (chips.isNotEmpty) return chips.first;
    for (final c in comparisons) {
      final watch = c.yesterdayWatchFor.trim();
      if (watch.isNotEmpty) return watch;
    }
    return 'what keeps repeating';
  }

  String _body(
    String theme,
    List<String> chips,
    int completedCount,
    int comparisonCount,
  ) {
    final count = comparisonCount >= completedCount
        ? comparisonCount
        : completedCount;
    if (chips.length >= 2) {
      return '$theme showed up more than once this week, especially around '
          '${chips[0]} and ${chips[1]}.';
    }
    if (chips.isNotEmpty) {
      return '$theme showed up more than once this week, especially around '
          '${chips.first}.';
    }
    return ConsumerUiCopy.weeklyRecapBodyFallback(count);
  }
}
