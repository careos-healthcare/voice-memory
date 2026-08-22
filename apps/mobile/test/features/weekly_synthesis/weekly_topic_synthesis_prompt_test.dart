import 'package:archiveme_mobile/features/weekly_synthesis/domain/recurrent_topic_cluster.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/services/weekly_topic_synthesis_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Gemma weekly synthesis JSON', () {
    const topics = [
      RecurrentTopicCluster(
        normalizedLabel: 'work pressure',
        displayLabel: 'Work pressure',
        mentionCount: 3,
        nodeIds: ['a'],
        entryIds: ['e1'],
      ),
    ];

    final draft = WeeklyTopicSynthesisPrompt.parse(
      rawCompletion: '''
{
  "headline": "Work kept showing up",
  "summary": "You mentioned work pressure several times this week.",
  "recurringThemes": ["Work pressure"]
}
''',
      topics: topics,
    );

    expect(draft.headline, 'Work kept showing up');
    expect(draft.summary, contains('work pressure'));
    expect(draft.recurringThemeLabels, ['Work pressure']);
  });
}
