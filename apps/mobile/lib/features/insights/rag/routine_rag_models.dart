import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/design/user_facing_date.dart';

/// Morning or evening journal routine target.
enum JournalRoutineKind {
  morning,
  evening;

  String get label => switch (this) {
    JournalRoutineKind.morning => 'Morning',
    JournalRoutineKind.evening => 'Evening',
  };
}

/// One retrieved slice of the user's local archive used as RAG context.
class RagContextChunk {
  const RagContextChunk({
    required this.entryId,
    required this.createdAt,
    required this.mood,
    required this.themes,
    required this.summary,
    required this.relevanceScore,
    this.tensionOrContradiction,
    this.nextSmallAction,
  });

  final String entryId;
  final DateTime createdAt;
  final String mood;
  final List<String> themes;
  final String summary;
  final double relevanceScore;
  final String? tensionOrContradiction;
  final String? nextSmallAction;

  String get formattedDate => formatUserFacingDate(createdAt);
}

/// Query profile for local reflection retrieval.
class RoutineRagQuery {
  const RoutineRagQuery({
    required this.routine,
    this.currentMood,
    this.recurringThemes = const [],
    this.emotionalIntensity,
    this.semanticQuery,
    this.maxChunks = 6,
  });

  final JournalRoutineKind routine;
  final String? currentMood;
  final List<String> recurringThemes;
  final int? emotionalIntensity;
  final String? semanticQuery;
  final int maxChunks;
}

/// Privacy-first prompts generated entirely on-device.
class RoutineJournalPrompt {
  const RoutineJournalPrompt({
    required this.routine,
    required this.primaryPrompt,
    required this.supportingPrompts,
    required this.contextChunks,
    this.reflectionSeed,
    this.usedOnnx = false,
  });

  final JournalRoutineKind routine;
  final String primaryPrompt;
  final List<String> supportingPrompts;
  final List<RagContextChunk> contextChunks;
  final ReflectionDto? reflectionSeed;
  final bool usedOnnx;
}
