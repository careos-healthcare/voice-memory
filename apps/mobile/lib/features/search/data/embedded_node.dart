import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:objectbox/objectbox.dart';

/// On-device HNSW vector index row for hybrid semantic retrieval.
@Entity()
class EmbeddedNode {
  EmbeddedNode({required this.entryId, required this.embedding});

  @Id()
  int id = 0;

  @Unique(onConflict: ConflictStrategy.replace)
  late String entryId;

  @HnswIndex(
    dimensions: localTranscriptEmbeddingDimensions,
    distanceType: VectorDistanceType.cosine,
  )
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;
}
