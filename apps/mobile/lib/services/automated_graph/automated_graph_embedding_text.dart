import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_text.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';

/// Canonical text embedded when building automated knowledge-graph edges.
abstract final class AutomatedGraphEmbeddingText {
  AutomatedGraphEmbeddingText._();

  static const topSimilarEntries = 3;

  /// Prefers the structured journal transcript, falling back to reflection text.
  static String fromEntry(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.length >= ReflectionTextProcessor.minTextChars) {
      return transcript;
    }
    return ReflectionEmbeddingText.fromEntry(entry);
  }
}
