import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/insight_engine/reciprocal_rank_fusion.dart';

/// Merges FTS5 keyword and vec0 semantic ranked lists into a single hybrid ranking.
final class HybridSearchResultMerger {
  const HybridSearchResultMerger({ReciprocalRankFusion? fusion})
      : _fusion = fusion ?? const ReciprocalRankFusion();

  final ReciprocalRankFusion _fusion;

  /// RRF smoothing constant used when fusing ranked lists.
  int get fusionK => _fusion.k;

  /// Fuses [keywordHits] and [semanticHits] with reciprocal rank fusion (RRF).
  ///
  /// Either channel may be empty; a single-channel result preserves that
  /// channel's ordering with rank metadata attached.
  List<HybridSearchHit> mergeAndRank({
    required List<KeywordSearchHit> keywordHits,
    required List<SemanticSearchHit> semanticHits,
    int limit = 20,
  }) {
    if (limit <= 0) return const [];

    final keywordIds =
        keywordHits.map((hit) => hit.entryId).toList(growable: false);
    final semanticIds =
        semanticHits.map((hit) => hit.entryId).toList(growable: false);

    if (keywordIds.isEmpty && semanticIds.isEmpty) return const [];

    if (keywordIds.isNotEmpty && semanticIds.isEmpty) {
      return _hitsFromKeywordOnly(keywordHits, limit);
    }
    if (semanticIds.isNotEmpty && keywordIds.isEmpty) {
      return _hitsFromSemanticOnly(semanticHits, limit);
    }

    final fusedIds = _fusion.fuse(
      [keywordIds, semanticIds],
      limit: limit,
    );

    final keywordRankById = {
      for (final hit in keywordHits) hit.entryId: hit.rank,
    };
    final semanticRankById = {
      for (final hit in semanticHits) hit.entryId: hit.rank,
    };

    final fusedScores = <String, double>{};
    for (final list in [keywordIds, semanticIds]) {
      for (var index = 0; index < list.length; index++) {
        final entryId = list[index];
        fusedScores[entryId] =
            (fusedScores[entryId] ?? 0) + 1 / (_fusion.k + index + 1);
      }
    }

    return fusedIds
        .map(
          (entryId) => HybridSearchHit(
            entryId: entryId,
            score: fusedScores[entryId] ?? 0,
            keywordRank: keywordRankById[entryId],
            vectorRank: semanticRankById[entryId],
          ),
        )
        .toList(growable: false);
  }

  List<HybridSearchHit> _hitsFromKeywordOnly(
    List<KeywordSearchHit> keywordHits,
    int limit,
  ) {
    return keywordHits
        .take(limit)
        .map(
          (hit) => HybridSearchHit(
            entryId: hit.entryId,
            score: 1 / (_fusion.k + hit.rank),
            keywordRank: hit.rank,
          ),
        )
        .toList(growable: false);
  }

  List<HybridSearchHit> _hitsFromSemanticOnly(
    List<SemanticSearchHit> semanticHits,
    int limit,
  ) {
    return semanticHits
        .take(limit)
        .map(
          (hit) => HybridSearchHit(
            entryId: hit.entryId,
            score: 1 / (_fusion.k + hit.rank),
            vectorRank: hit.rank,
          ),
        )
        .toList(growable: false);
  }
}
