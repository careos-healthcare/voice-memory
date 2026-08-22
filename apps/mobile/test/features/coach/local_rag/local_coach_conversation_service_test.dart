import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_journal_rag_retriever.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_onnx_response_synthesizer.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_models.dart';
import 'package:archiveme_mobile/features/coach/local_rag/local_coach_conversation_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRetriever implements CoachRagRetriever {
  _FakeRetriever(this._chunks);

  final List<CoachRagContextChunk> _chunks;

  @override
  Future<List<CoachRagContextChunk>> retrieve({
    required CoachRagQuery query,
    List<JournalEntry>? localEntries,
  }) async {
    return _chunks;
  }
}

class _FakeSynthesizer implements CoachResponseSynthesizer {
  @override
  Future<CoachConversationResponse> synthesize({
    required CoachRagQuery query,
    required List<CoachRagContextChunk> contextChunks,
    List<CoachConversationTurn> conversationHistory = const [],
    String entryId = 'coach-conversation',
  }) async {
    return CoachConversationResponse(
      primaryFollowUp: 'What feels unresolved here: ${query.userQuery}',
      coachingPrompts: const ['Where does work keep showing up for you?'],
      contextChunks: contextChunks,
      acknowledgment: 'You noticed the shutdown again.',
      reflectionSeed: ReflectionDto(
        mood: 'reflective',
        emotionalIntensity: 6,
        recurringThemes: const ['work'],
        concreteObservation: 'You noticed the shutdown again.',
        tensionOrContradiction: query.liveVoicePrompt,
      ),
      citedEntryIds: contextChunks.map((chunk) => chunk.entryId).toList(),
      usedOnnx: false,
      usedGenerativeLlm: false,
    );
  }
}

void main() {
  test('respond retrieves context and synthesizes offline coaching reply', () async {
    final service = LocalCoachConversationService(
      retriever: _FakeRetriever([
        CoachRagContextChunk(
          entryId: 'entry-1',
          createdAt: DateTime.utc(2026, 8, 15),
          excerpt: 'I avoided the hard conversation again.',
          relevanceScore: 0.88,
          mood: 'anxious',
        ),
      ]),
      synthesizer: _FakeSynthesizer(),
    );

    final response = await service.respond(
      userQuery: 'Why do I keep avoiding this?',
      liveVoicePrompt: 'I shut down in the meeting.',
      archiveEntries: [
        JournalEntry(
          id: 'entry-1',
          createdAt: DateTime.utc(2026, 8, 15),
          transcript: 'I avoided the hard conversation again.',
          durationSeconds: 0,
          reflection: const Reflection(
            mood: 'anxious',
            emotionalIntensity: 7,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Avoidance again',
            repeatedSignal: '',
          ),
        ),
      ],
    );

    expect(response.primaryFollowUp, contains('Why do I keep avoiding this?'));
    expect(response.hadRetrieval, isTrue);
    expect(response.citedEntryIds, ['entry-1']);
    expect(response.coachingPrompts, isNotEmpty);
  });

  test('respond rejects empty user query', () async {
    final service = LocalCoachConversationService(
      retriever: _FakeRetriever(const []),
      synthesizer: _FakeSynthesizer(),
    );

    expect(
      () => service.respond(userQuery: '   '),
      throwsArgumentError,
    );
  });
}
