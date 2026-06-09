import 'pattern_memory_model.dart';
import 'pattern_next_action_model.dart';
import 'pattern_progress_model.dart';
import 'weekly_pattern_recap_model.dart';

/// Builds the once-a-week payoff from how a pattern moved across the week.
class WeeklyPatternRecapEngine {
  const WeeklyPatternRecapEngine();

  static const int minCheckIns = 4;

  WeeklyPatternRecap build(
    PatternMemory memory,
    PatternProgressMoment? progress,
    PatternNextAction? action, {
    DateTime? now,
  }) {
    final reference = now ?? memory.updatedAt;
    final weekStart = _startOfWeek(reference);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final count = memory.checkInCount;

    if (count < minCheckIns) {
      return WeeklyPatternRecap(
        id: _id(memory.id, weekStart, WeeklyPatternRecapType.notEnoughYet),
        memoryId: memory.id,
        createdAt: reference,
        weekStart: weekStart,
        weekEnd: weekEnd,
        type: WeeklyPatternRecapType.notEnoughYet,
        patternTitle: memory.patternTitle,
        headline: 'Not enough checks yet this week.',
        body: 'A few more checks and this week starts to add up.',
        checkInCount: count,
        shouldShow: false,
      );
    }

    final type = _typeFor(memory, progress);
    final spec = _specFor(type, memory, count);
    return WeeklyPatternRecap(
      id: _id(memory.id, weekStart, type),
      memoryId: memory.id,
      createdAt: reference,
      weekStart: weekStart,
      weekEnd: weekEnd,
      type: type,
      patternTitle: memory.patternTitle,
      headline: spec.headline,
      body: spec.body,
      usefulLine: spec.usefulLine,
      nextQuestion: spec.nextQuestion,
      checkInCount: count,
      shouldShow: true,
    );
  }

  WeeklyPatternRecapType _typeFor(
    PatternMemory memory,
    PatternProgressMoment? progress,
  ) {
    // Priority: heavier > lighter > changing > repeated > notEnoughYet.
    if (memory.heavierCount >= 2 && memory.heavierCount > memory.lighterCount) {
      return WeeklyPatternRecapType.heavier;
    }
    if (memory.lighterCount >= 2 && memory.lighterCount >= memory.heavierCount) {
      return WeeklyPatternRecapType.lighter;
    }
    if (memory.changedCount >= 2 ||
        memory.status == PatternMemoryStatus.changing ||
        progress?.type == PatternProgressType.changing) {
      return WeeklyPatternRecapType.changing;
    }
    return WeeklyPatternRecapType.repeated;
  }

  _RecapSpec _specFor(
    WeeklyPatternRecapType type,
    PatternMemory memory,
    int count,
  ) {
    switch (type) {
      case WeeklyPatternRecapType.heavier:
        return _RecapSpec(
          headline: 'This pattern felt heavier this week.',
          body: 'You checked it $count times and it may need more attention.',
          usefulLine: _first(memory.harderMoments, 'What made it harder: '),
          nextQuestion: 'What made it heavier?',
        );
      case WeeklyPatternRecapType.lighter:
        return _RecapSpec(
          headline: 'This pattern felt lighter this week.',
          body: 'You checked it $count times and it felt lighter '
              'more than heavier.',
          usefulLine: _first(memory.helpedMoments, 'What helped: '),
          nextQuestion: 'What helped make it lighter?',
        );
      case WeeklyPatternRecapType.changing:
        return _RecapSpec(
          headline: 'This pattern changed this week.',
          body: 'You checked it $count times and it was not just a repeat.',
          usefulLine: null,
          nextQuestion: 'What was different?',
        );
      case WeeklyPatternRecapType.repeated:
        return _RecapSpec(
          headline: 'This pattern kept showing up this week.',
          body: 'You checked it $count times and caught it more than once.',
          usefulLine: _first(memory.commonBeforeMoments, 'It often starts around: '),
          nextQuestion: 'What happens right before it starts?',
        );
      case WeeklyPatternRecapType.notEnoughYet:
        return const _RecapSpec(
          headline: 'Not enough checks yet this week.',
          body: 'A few more checks and this week starts to add up.',
          usefulLine: null,
          nextQuestion: null,
        );
    }
  }

  String? _first(List<String> values, String prefix) {
    for (final v in values) {
      final trimmed = v.trim();
      if (trimmed.isNotEmpty) return '$prefix$trimmed';
    }
    return null;
  }

  DateTime _startOfWeek(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - DateTime.monday));
  }

  String _id(String memoryId, DateTime weekStart, WeeklyPatternRecapType type) {
    final stamp =
        '${weekStart.year}${_two(weekStart.month)}${_two(weekStart.day)}';
    return 'wr_${memoryId}_${stamp}_${type.id}';
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';
}

class _RecapSpec {
  const _RecapSpec({
    required this.headline,
    required this.body,
    required this.usefulLine,
    required this.nextQuestion,
  });

  final String headline;
  final String body;
  final String? usefulLine;
  final String? nextQuestion;
}
