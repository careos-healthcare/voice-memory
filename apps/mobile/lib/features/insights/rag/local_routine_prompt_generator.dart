import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';

/// Feeds RAG context into the local ONNX reflection model and maps outputs
/// into privacy-first routine prompts.
class LocalRoutinePromptGenerator {
  LocalRoutinePromptGenerator({required LocalReflectionDataSource reflectionModel})
    : _reflectionModel = reflectionModel;

  final LocalReflectionDataSource _reflectionModel;

  Future<RoutineJournalPrompt> generate({
    required JournalRoutineKind routine,
    required List<RagContextChunk> contextChunks,
    String? currentMood,
    List<String> recurringThemes = const [],
  }) async {
    final augmentedTranscript = _buildAugmentedTranscript(
      routine: routine,
      chunks: contextChunks,
      currentMood: currentMood,
      recurringThemes: recurringThemes,
    );

    final inference = await _reflectionModel.inferFromTranscript(
      transcript: augmentedTranscript,
      entryId: 'routine-${routine.name}',
    );

    final prompts = _composePrompts(
      routine: routine,
      chunks: contextChunks,
      reflection: inference.reflection,
    );

    return RoutineJournalPrompt(
      routine: routine,
      primaryPrompt: prompts.primary,
      supportingPrompts: prompts.supporting,
      contextChunks: contextChunks,
      reflectionSeed: inference.reflection,
      usedOnnx: inference.usedOnnx,
    );
  }

  static String _buildAugmentedTranscript({
    required JournalRoutineKind routine,
    required List<RagContextChunk> chunks,
    String? currentMood,
    List<String> recurringThemes = const [],
  }) {
    final buffer = StringBuffer()
      ..writeln('Archive context (local only):');

    for (final chunk in chunks.take(4)) {
      buffer.writeln(
        '- ${chunk.formattedDate}: mood ${chunk.mood}; ${chunk.summary}',
      );
    }

    buffer
      ..writeln()
      ..writeln('Routine: ${routine.label.toLowerCase()} check-in');

    if (currentMood != null && currentMood.trim().isNotEmpty) {
      buffer.writeln('Current mood: ${currentMood.trim()}');
    }

    if (recurringThemes.isNotEmpty) {
      buffer.writeln('Recurring themes: ${recurringThemes.join(', ')}');
    }

    buffer.writeln(switch (routine) {
      JournalRoutineKind.morning =>
        'What feels most important to name honestly this morning?',
      JournalRoutineKind.evening =>
        'What is still unresolved before you rest tonight?',
    });

    return buffer.toString().trim();
  }

  static ({String primary, List<String> supporting}) _composePrompts({
    required JournalRoutineKind routine,
    required List<RagContextChunk> chunks,
    required ReflectionDto reflection,
  }) {
    final primary = switch (routine) {
      JournalRoutineKind.morning => _morningPrimary(reflection, chunks),
      JournalRoutineKind.evening => _eveningPrimary(reflection, chunks),
    };

    final supporting = <String>[
      if ((reflection.concreteObservation ?? '').trim().isNotEmpty)
        'Name one concrete moment: ${reflection.concreteObservation!.trim()}',
      if ((reflection.tensionOrContradiction ?? '').trim().isNotEmpty)
        'Where is the pull-between? ${reflection.tensionOrContradiction!.trim()}',
      if ((reflection.nextSmallAction ?? '').trim().isNotEmpty)
        'One small step you named before: ${reflection.nextSmallAction!.trim()}',
      for (final chunk in chunks.take(2))
        'On ${chunk.formattedDate} you noted: ${chunk.summary}',
    ];

    return (
      primary: primary,
      supporting: supporting.take(3).toList(growable: false),
    );
  }

  static String _morningPrimary(
    ReflectionDto reflection,
    List<RagContextChunk> chunks,
  ) {
    final theme = reflection.recurringThemes.isNotEmpty
        ? reflection.recurringThemes.first
        : chunks.isNotEmpty && chunks.first.themes.isNotEmpty
        ? chunks.first.themes.first
        : null;

    if (theme != null) {
      return 'This morning, what do you want to do differently with $theme?';
    }
    if ((reflection.nextSmallAction ?? '').trim().isNotEmpty) {
      return 'Will you take this step today: ${reflection.nextSmallAction!.trim()}?';
    }
    return 'What feels honest to carry into today — in one sentence?';
  }

  static String _eveningPrimary(
    ReflectionDto reflection,
    List<RagContextChunk> chunks,
  ) {
    if ((reflection.tensionOrContradiction ?? '').trim().isNotEmpty) {
      return 'Before you rest: ${reflection.tensionOrContradiction!.trim()}';
    }
    final chunkTension = chunks
        .map((chunk) => chunk.tensionOrContradiction?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (chunkTension.isNotEmpty) {
      return 'This theme appeared before: $chunkTension — what shifted today?';
    }
    return 'What do you want to leave on the page before tonight ends?';
  }
}
