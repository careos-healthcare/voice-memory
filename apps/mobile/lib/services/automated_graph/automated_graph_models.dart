import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';

/// Result of automated graph building for one journal entry.
final class AutomatedGraphResult {
  const AutomatedGraphResult({
    required this.entryId,
    required this.embeddingStored,
    required this.similarEntries,
    required this.edgesStored,
  });

  final String entryId;
  final bool embeddingStored;
  final List<VectorSearchHit> similarEntries;
  final int edgesStored;
}
