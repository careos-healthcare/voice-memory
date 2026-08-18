import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// Plain-language confidence labels for evidence-trail surfaces.
abstract final class EvidenceConfidenceBandCopy {
  EvidenceConfidenceBandCopy._();

  static const strongPattern = 'Strong pattern';
  static const possiblePattern = 'Possible pattern';
  static const singleMention = 'Single mention';

  static String labelFor({
    required PatternMatchConfidenceBand band,
    required int sourceCount,
  }) {
    if (sourceCount <= 1) return singleMention;
    return switch (band) {
      PatternMatchConfidenceBand.strong ||
      PatternMatchConfidenceBand.solid =>
        strongPattern,
      PatternMatchConfidenceBand.emerging ||
      PatternMatchConfidenceBand.weak =>
        possiblePattern,
    };
  }

  static String summaryFor({
    required PatternMatchConfidenceBand band,
    required int sourceCount,
  }) {
    final label = labelFor(band: band, sourceCount: sourceCount);
    if (sourceCount <= 1) {
      return '$label — one journal moment cites this insight.';
    }
    return '$label — $sourceCount journal moments cite this insight.';
  }
}
