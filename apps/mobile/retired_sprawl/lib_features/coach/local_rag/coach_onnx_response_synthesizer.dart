import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_models.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_prompt_builder.dart';
import 'package:archiveme_mobile/features/reflections/data/onnx_llm_reflection_extractor.dart';

/// Maps local ONNX reflection output into conversational coaching responses.
abstract interface class CoachResponseSynthesizer {
  Future<CoachConversationResponse> synthesize({
    required CoachRagQuery query,
    required List<CoachRagContextChunk> contextChunks,
    List<CoachConversationTurn> conversationHistory,
    String entryId,
  });
}

class CoachOnnxResponseSynthesizer implements CoachResponseSynthesizer {
  CoachOnnxResponseSynthesizer({
    required LocalReflectionExtractor reflectionExtractor,
  }) : _reflectionExtractor = reflectionExtractor;

  final LocalReflectionExtractor _reflectionExtractor;

  static Future<CoachOnnxResponseSynthesizer> create({
    LocalReflectionExtractor? reflectionExtractor,
  }) async {
    return CoachOnnxResponseSynthesizer(
      reflectionExtractor:
          reflectionExtractor ?? await LocalReflectionExtractor.create(),
    );
  }

  Future<CoachConversationResponse> synthesize({
    required CoachRagQuery query,
    required List<CoachRagContextChunk> contextChunks,
    List<CoachConversationTurn> conversationHistory = const [],
    String entryId = 'coach-conversation',
  }) async {
    final augmentedTranscript = CoachRagPromptBuilder.buildAugmentedTranscript(
      query: query,
      contextChunks: contextChunks,
      conversationHistory: conversationHistory,
    );

    final extraction = await _reflectionExtractor.extract(
      transcript: augmentedTranscript,
      entryId: entryId,
    );

    return _composeResponse(
      reflection: extraction.reflection,
      contextChunks: contextChunks,
      usedOnnx: extraction.usedOnnx,
      usedGenerativeLlm: extraction.usedGenerativeLlm,
      query: query,
    );
  }

  CoachConversationResponse _composeResponse({
    required ReflectionDto reflection,
    required List<CoachRagContextChunk> contextChunks,
    required bool usedOnnx,
    required bool usedGenerativeLlm,
    required CoachRagQuery query,
  }) {
    final primary = _primaryFollowUp(reflection, query);
    final prompts = _supportingPrompts(reflection, contextChunks);

    return CoachConversationResponse(
      primaryFollowUp: primary,
      coachingPrompts: prompts,
      contextChunks: contextChunks,
      acknowledgment: _acknowledgment(reflection),
      groundedSummary: reflection.concreteObservation?.trim(),
      reflectionSeed: reflection,
      citedEntryIds: contextChunks.map((chunk) => chunk.entryId).toList(),
      usedOnnx: usedOnnx,
      usedGenerativeLlm: usedGenerativeLlm,
    );
  }

  static String _primaryFollowUp(ReflectionDto reflection, CoachRagQuery query) {
    final action = reflection.nextSmallAction?.trim();
    if (action != null && action.isNotEmpty) {
      return 'One honest next step: $action';
    }

    final tension = reflection.tensionOrContradiction?.trim();
    if (tension != null && tension.isNotEmpty) {
      return 'What feels unresolved here: $tension';
    }

    final livePrompt = query.liveVoicePrompt?.trim();
    if (livePrompt != null && livePrompt.isNotEmpty) {
      return 'You said “$livePrompt” — what part of that do you want to understand differently?';
    }

    return 'What feels most true about “${query.userQuery.trim()}” when you look at your archive?';
  }

  static List<String> _supportingPrompts(
    ReflectionDto reflection,
    List<CoachRagContextChunk> contextChunks,
  ) {
    final prompts = <String>[];

    for (final theme in reflection.recurringThemes.take(2)) {
      final trimmed = theme.trim();
      if (trimmed.isEmpty) continue;
      prompts.add('Where does $trimmed keep showing up for you?');
    }

    for (final pattern in reflection.patternObservations.take(2)) {
      final trimmed = pattern.trim();
      if (trimmed.isEmpty) continue;
      prompts.add(trimmed);
    }

    for (final chunk in contextChunks.take(2)) {
      prompts.add(
        'On ${chunk.formattedDate} you noted: ${chunk.excerpt}',
      );
    }

    if (prompts.isEmpty) {
      prompts.add('What would you want your future self to remember from this?');
    }

    return prompts.take(4).toList(growable: false);
  }

  static String? _acknowledgment(ReflectionDto reflection) {
    final observation = reflection.concreteObservation?.trim();
    if (observation != null && observation.isNotEmpty) {
      return observation;
    }
    final repeated = reflection.repeatedSignal?.trim();
    if (repeated != null && repeated.isNotEmpty) {
      return repeated;
    }
    return null;
  }
}
