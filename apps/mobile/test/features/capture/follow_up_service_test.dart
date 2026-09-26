import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/capture/services/follow_up_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/record/post_save_follow_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JournalEntry current() {
    return JournalEntry(
      id: 'today',
      createdAt: DateTime.utc(2026, 9, 26, 12),
      transcript: 'The river was quiet this morning.',
      durationSeconds: 6,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
  }

  test('stays quiet while post-save follow-up is off', () async {
    var lookedUp = false;
    final service = FollowUpService(
      readEmbedding: (_) async {
        lookedUp = true;
        return const [1];
      },
    );

    final followUp = await service.forEntry(current());

    expect(followUp, isNull);
    expect(lookedUp, isFalse);
  });

  test('cites the closest entry older than 7 days', () async {
    final past = SimilarEntry(
      id: 'past-1',
      createdAt: DateTime.utc(2024, 3, 2, 12),
      transcript: 'I keep coming back to the river in the morning.',
      cosineSimilarity: 0.9,
    );
    int? seenDays;
    int? seenLimit;
    final service = FollowUpService(
      readEmbedding: (_) async => const [1],
      findSimilar: (vector, {int excludeWithinDays = 7, int limit = 1}) async {
        seenDays = excludeWithinDays;
        seenLimit = limit;
        return [past];
      },
    );

    final followUp = await service.forEntry(current(), enabled: true);

    expect(seenDays, 7);
    expect(seenLimit, 1);
    expect(
      followUp!.prompt,
      "On 2 March 2024 the user said: 'I keep coming back to the river in the morning.'. "
      "Today they said: 'The river was quiet this morning.'. "
      'Ask a single, gentle question about what has changed or evolved.',
    );
    expect(
      followUp.citation,
      'On 2 March 2024 you said "I keep coming back to the river in the morning.". '
      'Today you said "The river was quiet this morning.".',
    );
    expect(followUp.question, followUpQuestion);
  });

  testWidgets('shows the cited quotes above the question', (tester) async {
    const followUp = FollowUpReflection(
      pastEntryId: 'past-1',
      prompt: 'prompt',
      citation:
          'On 2 March 2024 you said "I keep coming back to the river.". '
          'Today you said "The river was quiet.".',
      question: followUpQuestion,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FollowUpCitationBlock(
            followUp: followUp,
            currentEntryId: 'today',
          ),
        ),
      ),
    );

    expect(
      find.text(
        'On 2 March 2024 you said "I keep coming back to the river.". '
        'Today you said "The river was quiet.".',
      ),
      findsOneWidget,
    );
    expect(find.text(followUpQuestion), findsOneWidget);
    final citationTop = tester.getTopLeft(
      find.byKey(const Key('post_save_follow_up_citation')),
    );
    final questionTop = tester.getTopLeft(
      find.byKey(const Key('post_save_follow_up_question')),
    );
    expect(citationTop.dy, lessThan(questionTop.dy));
  });
}
