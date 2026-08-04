import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/weekly_story/weekly_story_engine.dart';
import 'package:voicememory_mobile/features/weekly_story/weekly_story_models.dart';

void main() {
  test('weekly retrospective narrates only supplied story insights', () {
    final story = WeeklyArchiveStory(
      weekStart: DateTime.utc(2026, 7, 13),
      weekEnd: DateTime.utc(2026, 7, 19),
      topThemes: const [
        WeeklyThemeLine(label: 'Capacity', count: 3, priorCount: 1),
        WeeklyThemeLine(label: 'Work', count: 2, priorCount: 2),
      ],
      growingThemes: const [
        WeeklyThemeLine(label: 'Capacity', count: 3, priorCount: 1),
      ],
      decliningThemes: const [
        WeeklyThemeLine(label: 'Stress', count: 1, priorCount: 3),
      ],
      primaryBelief: 'Checking capacity before agreeing helps',
      reflectionCountThisWeek: 5,
      hasSufficientData: true,
    );

    final narrative = const WeeklyStoryEngine().buildAudioRetrospective(story);

    expect(narrative, startsWith('Weekly Audio Retrospective.'));
    expect(narrative, isNot(contains('five')));
    expect(narrative, contains('5 moments'));
    expect(narrative, contains('Capacity and Work'));
    expect(narrative, contains('returned more often'));
    expect(narrative, contains('appeared less often'));
    expect(narrative, contains(story.primaryBelief));
  });
}
