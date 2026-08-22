import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_evidence_confidence.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_reveal_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_reveal_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_review_model.dart';

/// Builds a [PressurePatternReview] from local pressure check-in records.
///
/// Pure and deterministic. Reuses [PressurePatternRevealEngine] for the
/// dominant pattern, repeated trigger/context, and likely cost so the review
/// never disagrees with the reveal. The "what changed" section is only
/// populated when the evidence actually supports it.
class PressurePatternReviewEngine {
  const PressurePatternReviewEngine();

  static const _revealEngine = PressurePatternRevealEngine();
  static const _confidenceEngine = PressureEvidenceConfidenceEngine();

  PressurePatternReview build(List<PressureCheckInRecord> records) {
    if (records.length < PressurePatternReview.minEntries) {
      return PressurePatternReview.insufficient(records.length);
    }

    final reveal = _revealEngine.build(records);
    final confidence = _confidenceEngine.fromRecords(records);

    return PressurePatternReview(
      hasReview: true,
      entryCount: records.length,
      confidence: confidence,
      repeatingSummary: _repeatingSummary(reveal),
      strongestTrigger: reveal.strongestTrigger,
      likelyCost: reveal.likelyCost,
      changeSummary: _changeSummary(records),
    );
  }

  String _repeatingSummary(PressurePatternReveal reveal) {
    final phrase = reveal.dominantPhrase ?? 'keep going under pressure';
    final buffer = StringBuffer(
      'Across your entries so far, one moment keeps repeating: '
      'you often $phrase',
    );
    final context = reveal.repeatedContextLabel;
    if (context != null) {
      buffer.write(', most visibly around ${context.toLowerCase()}');
    }
    buffer.write('.');
    return buffer.toString();
  }

  /// Only reports a change the records actually show. The one honest,
  /// structural signal available: the user has started choosing to stop when
  /// they didn't in their first entry. Returns null otherwise — the card
  /// shows a no-overclaim fallback instead of an invented change.
  String? _changeSummary(List<PressureCheckInRecord> records) {
    final ordered = [...records]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = ordered.first;
    if (first.choseToStop) return null;

    final laterStops = ordered
        .skip(1)
        .where((record) => record.choseToStop)
        .length;
    if (laterStops == 0) return null;

    final times = laterStops == 1 ? 'once' : '$laterStops times';
    return "In your first entry you didn't stop. Since then you've chosen "
        'to stop $times — a shift that may be worth keeping, so far.';
  }
}