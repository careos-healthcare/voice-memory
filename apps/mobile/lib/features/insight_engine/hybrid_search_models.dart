/// A single hybrid retrieval hit after RRF fusion.
class HybridSearchHit {
  const HybridSearchHit({
    required this.entryId,
    required this.score,
    this.keywordRank,
    this.vectorRank,
  });

  final String entryId;
  final double score;
  final int? keywordRank;
  final int? vectorRank;
}

/// Cosine-similarity hit from local vector retrieval.
class VectorSearchHit {
  const VectorSearchHit({
    required this.entryId,
    required this.cosineSimilarity,
  });

  final String entryId;
  final double cosineSimilarity;
}

/// Embedding width for on-device transcript / local LM hybrid search (384-d).
const localTranscriptEmbeddingDimensions = 384;

/// Embedding width for ONNX vision models and Gemini fact-ledger vectors (768-d).
const imageEmbeddingDimensions = 768;

/// Transcript hybrid-search dimension — alias kept for existing call sites.
const memoryTranscriptEmbeddingDimensions = localTranscriptEmbeddingDimensions;
