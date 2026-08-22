import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';

/// Service-layer output for a gated pattern comparison request.
class PatternComparisonPlan {
  const PatternComparisonPlan({
    required this.systemPrompt,
    required this.userPrompt,
    required this.currentMoment,
    required this.visibleHistoricalMoments,
    required this.totalMomentCount,
    required this.isPro,
    required this.hasDismissedProTrailPrompt,
  });

  final String systemPrompt;
  final String userPrompt;
  final ArchiveMomentRecord currentMoment;
  final List<ArchiveMomentRecord> visibleHistoricalMoments;
  final int totalMomentCount;
  final bool isPro;
  final bool hasDismissedProTrailPrompt;
}