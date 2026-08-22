import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';

/// Builds the "here is what changed" payoff from a pattern memory.
///
/// Pure logic. Uses "may be" when interpreting direction so it never
/// overclaims what the person's check-ins actually show.
class PatternProgressEngine {
  const PatternProgressEngine();

  static const int _minCheckIns = 3;

  PatternProgressMoment build(PatternMemory memory) {
    final count = memory.checkInCount;
    final type = _type(memory);
    final shouldShow =
        count >= _minCheckIns && type != PatternProgressType.notEnoughYet;

    String? beforeLine;
    String? helpedLine;
    final String headline;
    final String body;
    final String nextLine;

    switch (type) {
      case PatternProgressType.gettingLighter:
        headline = 'This pattern may be getting lighter.';
        body =
            'You have checked it $count times. '
            'Lately, it has felt lighter more than heavier.';
        if (memory.helpedMoments.isNotEmpty) {
          helpedLine = 'What helped: ${memory.helpedMoments.first}';
        }
        nextLine = 'Next, watch what helps before it gets heavy.';
      case PatternProgressType.gettingHeavier:
        headline = 'This pattern may be getting heavier.';
        body =
            'You have checked it $count times. '
            'Lately, it has felt heavier more than lighter.';
        if (memory.harderMoments.isNotEmpty) {
          beforeLine = 'What made it harder: ${memory.harderMoments.first}';
        }
        nextLine = 'Next, watch what makes it heavier.';
      case PatternProgressType.stillRepeating:
        headline = 'This pattern is still showing up.';
        body =
            'You have caught it $count times. '
            'The useful part is that you are noticing the moment.';
        if (memory.commonBeforeMoments.isNotEmpty) {
          beforeLine =
              'It often starts around: ${memory.commonBeforeMoments.first}';
        }
        nextLine = 'Next, watch what happens right before it starts.';
      case PatternProgressType.changing:
        headline = 'This pattern is changing.';
        body =
            'You have checked it $count times, and today was not just a repeat.';
        nextLine = 'Next, watch what was different.';
      case PatternProgressType.notEnoughYet:
        headline = 'Keep checking this pattern.';
        body = 'A few more check-ins and ArchiveMe can show what changed.';
        nextLine = 'Next, check this pattern again.';
    }

    return PatternProgressMoment(
      id: 'pp_${memory.id}_$count',
      memoryId: memory.id,
      createdAt: memory.updatedAt,
      type: type,
      headline: headline,
      body: body,
      beforeLine: beforeLine,
      helpedLine: helpedLine,
      nextLine: nextLine,
      checkInCount: count,
      shouldShow: shouldShow,
    );
  }

  PatternProgressType _type(PatternMemory m) {
    if (m.checkInCount < _minCheckIns) return PatternProgressType.notEnoughYet;

    // Priority: heavier > lighter > changing > stillRepeating.
    if (m.heavierCount >= 2 && m.heavierCount > m.lighterCount) {
      return PatternProgressType.gettingHeavier;
    }
    if (m.lighterCount >= 2 && m.lighterCount >= m.heavierCount) {
      return PatternProgressType.gettingLighter;
    }
    if (m.changedCount >= 2 || m.status == PatternMemoryStatus.changing) {
      return PatternProgressType.changing;
    }
    if (m.showedAgainCount >= 2 &&
        m.showedAgainCount >= m.lighterCount &&
        m.showedAgainCount >= m.heavierCount) {
      return PatternProgressType.stillRepeating;
    }
    return PatternProgressType.notEnoughYet;
  }
}