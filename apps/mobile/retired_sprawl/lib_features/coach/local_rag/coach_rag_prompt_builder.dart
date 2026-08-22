import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_models.dart';

/// Builds augmented ONNX prompts for offline coach conversations.
abstract final class CoachRagPromptBuilder {
  CoachRagPromptBuilder._();

  static const _coachHeader = '''
Offline coach conversation (local only — no cloud):
Use ONLY the archive excerpts below. Do not invent facts.
Return reflection JSON with mood, emotionalIntensity, recurringThemes,
tensionOrContradiction, and nextSmallAction.
''';

  static String buildAugmentedTranscript({
    required CoachRagQuery query,
    required List<CoachRagContextChunk> contextChunks,
    List<CoachConversationTurn> conversationHistory = const [],
  }) {
    final buffer = StringBuffer()..writeln(_coachHeader.trim());

    if (contextChunks.isNotEmpty) {
      buffer.writeln('Retrieved archive excerpts:');
      for (final chunk in contextChunks.take(6)) {
        buffer.writeln(
          '- ${chunk.formattedDate} (mood ${chunk.mood.isEmpty ? 'unknown' : chunk.mood}): '
          '${chunk.excerpt}',
        );
      }
      buffer.writeln();
    } else {
      buffer.writeln('Retrieved archive excerpts: none indexed yet.');
      buffer.writeln();
    }

    if (conversationHistory.isNotEmpty) {
      buffer.writeln('Recent conversation:');
      for (final turn in conversationHistory.take(4)) {
        final label = turn.role == CoachConversationRole.user ? 'User' : 'Coach';
        buffer.writeln('- $label: ${turn.text}');
      }
      buffer.writeln();
    }

    buffer.writeln('User query: ${query.userQuery.trim()}');

    final livePrompt = query.liveVoicePrompt?.trim();
    if (livePrompt != null && livePrompt.isNotEmpty) {
      buffer.writeln('Live voice prompt: $livePrompt');
    }

    buffer.writeln(
      'Synthesize a contextual, privacy-first coaching follow-up grounded in the excerpts.',
    );

    return buffer.toString().trim();
  }
}
