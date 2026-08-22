import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_models.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildAugmentedTranscript includes query, voice prompt, and excerpts', () {
    final transcript = CoachRagPromptBuilder.buildAugmentedTranscript(
      query: const CoachRagQuery(
        userQuery: 'Why do I keep avoiding this conversation?',
        liveVoicePrompt: 'I noticed I shut down again today.',
      ),
      contextChunks: [
        CoachRagContextChunk(
          entryId: 'entry-1',
          createdAt: DateTime.utc(2026, 8, 15),
          excerpt: 'I avoided the hard conversation at work.',
          relevanceScore: 0.9,
          mood: 'anxious',
          themes: const ['work'],
        ),
      ],
      conversationHistory: [
        CoachConversationTurn.user('This keeps happening.'),
      ],
    );

    expect(transcript, contains('Offline coach conversation'));
    expect(transcript, contains('Why do I keep avoiding this conversation?'));
    expect(transcript, contains('Live voice prompt: I noticed I shut down again today.'));
    expect(transcript, contains('I avoided the hard conversation at work.'));
    expect(transcript, contains('User: This keeps happening.'));
  });
}
