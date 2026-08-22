import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/design/user_facing_date.dart';

/// A retrieved journal excerpt used as offline RAG context.
class CoachRagContextChunk {
  const CoachRagContextChunk({
    required this.entryId,
    required this.createdAt,
    required this.excerpt,
    required this.relevanceScore,
    this.mood = '',
    this.themes = const [],
    this.source = CoachRagChunkSource.reflectionEmbedding,
  });

  final String entryId;
  final DateTime createdAt;
  final String excerpt;
  final double relevanceScore;
  final String mood;
  final List<String> themes;
  final CoachRagChunkSource source;

  String get formattedDate => formatUserFacingDate(createdAt);
}

enum CoachRagChunkSource {
  reflectionEmbedding,
  transcriptEmbedding,
  recentFallback,
}

/// One turn in an offline coach thread.
class CoachConversationTurn {
  const CoachConversationTurn({
    required this.role,
    required this.text,
    required this.recordedAt,
  });

  factory CoachConversationTurn.user(String text, {DateTime? recordedAt}) {
    return CoachConversationTurn(
      role: CoachConversationRole.user,
      text: text.trim(),
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
    );
  }

  factory CoachConversationTurn.coach(String text, {DateTime? recordedAt}) {
    return CoachConversationTurn(
      role: CoachConversationRole.coach,
      text: text.trim(),
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
    );
  }

  final CoachConversationRole role;
  final String text;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };

  static CoachConversationTurn? fromJson(Map<String, dynamic> json) {
    final roleRaw = json['role'] as String?;
    final role = CoachConversationRole.values.firstWhere(
      (value) => value.name == roleRaw,
      orElse: () => CoachConversationRole.user,
    );
    final text = (json['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return null;
    final recordedAt = DateTime.tryParse(json['recordedAt'] as String? ?? '');
    return CoachConversationTurn(
      role: role,
      text: text,
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
    );
  }
}

enum CoachConversationRole { user, coach }

/// Privacy-first offline coaching response grounded in local journal RAG.
class CoachConversationResponse {
  const CoachConversationResponse({
    required this.primaryFollowUp,
    required this.coachingPrompts,
    required this.contextChunks,
    required this.usedOnnx,
    required this.usedGenerativeLlm,
    this.acknowledgment,
    this.groundedSummary,
    this.reflectionSeed,
    this.citedEntryIds = const [],
  });

  final String primaryFollowUp;
  final List<String> coachingPrompts;
  final List<CoachRagContextChunk> contextChunks;
  final String? acknowledgment;
  final String? groundedSummary;
  final ReflectionDto? reflectionSeed;
  final List<String> citedEntryIds;
  final bool usedOnnx;
  final bool usedGenerativeLlm;

  bool get hadRetrieval => contextChunks.isNotEmpty;
}

/// Query profile for local coach RAG retrieval.
class CoachRagQuery {
  const CoachRagQuery({
    required this.userQuery,
    this.liveVoicePrompt,
    this.maxChunks = 6,
  });

  final String userQuery;
  final String? liveVoicePrompt;
  final int maxChunks;

  String get combinedRetrievalText {
    final parts = <String>[
      userQuery.trim(),
      if (liveVoicePrompt != null && liveVoicePrompt!.trim().isNotEmpty)
        liveVoicePrompt!.trim(),
    ];
    return parts.join(' ').trim();
  }
}
