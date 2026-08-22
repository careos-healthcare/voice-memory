import 'package:archiveme_mobile/features/archive_evidence/archive_pattern_copy_guard.dart';
import 'package:archiveme_mobile/features/insights/archive_insight.dart';

/// Thresholds and rejection rules — no generic AI fluff.
abstract class InsightQualityRules {
  InsightQualityRules._();

  static const int minEvidenceCount = 3;
  static const int minConfidence = 55;

  static const List<String> rejectedGenericPhrases = [
    'you value growth',
    'you care about relationships',
    'you are resilient',
    'you value personal growth',
    'you care deeply about',
  ];

  static bool passes(ArchiveInsight insight) {
    if (insight.evidenceCount < minEvidenceCount) return false;
    if (insight.confidence < minConfidence) return false;
    if (insight.supportingEvidence.isEmpty) return false;
    if (!insight.supportingEvidence.any((e) => e.quote.trim().length >= 12)) {
      return false;
    }
    final blob = '${insight.title} ${insight.summary}'.toLowerCase();
    for (final banned in rejectedGenericPhrases) {
      if (blob.contains(banned)) return false;
    }
    if (ArchivePatternCopyGuard.isBlockedPatternText(insight.title)) {
      return false;
    }
    if (ArchivePatternCopyGuard.isBlockedPatternText(insight.summary)) {
      return false;
    }
    return !_looksGeneric(blob);
  }

  static bool _looksGeneric(String lower) {
    const vague = [
      'you are someone who',
      'you tend to be',
      'shows you value',
      'demonstrates resilience',
      'personal growth journey',
    ];
    return vague.any(lower.contains);
  }

  static List<ArchiveInsight> filter(Iterable<ArchiveInsight> insights) {
    return insights.where(passes).toList();
  }
}