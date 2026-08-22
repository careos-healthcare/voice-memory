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

/// BM25-ranked keyword hit from an FTS5 virtual table.
class KeywordSearchHit {
  const KeywordSearchHit({
    required this.entryId,
    required this.rank,
  });

  final String entryId;

  /// 1-based position in the keyword result list (best-first).
  final int rank;
}

/// Cosine-similarity hit from vec0 / sqlite-vector semantic retrieval.
class SemanticSearchHit {
  const SemanticSearchHit({
    required this.entryId,
    required this.rank,
    required this.cosineSimilarity,
  });

  final String entryId;

  /// 1-based position in the semantic result list (best-first).
  final int rank;
  final double cosineSimilarity;
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
