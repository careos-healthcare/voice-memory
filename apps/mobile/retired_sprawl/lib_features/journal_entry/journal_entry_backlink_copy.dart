import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// User-facing copy for reverse evidence backlinks on entry detail.
abstract final class JournalEntryBacklinkCopy {
  JournalEntryBacklinkCopy._();

  static const derivedInsightsTitle = 'Derived Insights from This Entry';
  static const derivedInsightsEmpty =
      'No active archive insights cite this moment yet.';
  static const highlightTooltipPrefix = 'Supports';

  static String confidenceLabel(PatternMatchConfidenceBand band) {
    return switch (band) {
      PatternMatchConfidenceBand.weak => 'Weak',
      PatternMatchConfidenceBand.emerging => 'Emerging',
      PatternMatchConfidenceBand.solid => 'Solid',
      PatternMatchConfidenceBand.strong => 'Strong',
    };
  }

  static String highlightTooltip({
    required String insightTitle,
    required PatternMatchConfidenceBand band,
  }) =>
      "$highlightTooltipPrefix '$insightTitle' • ${confidenceLabel(band)} Confidence";
}