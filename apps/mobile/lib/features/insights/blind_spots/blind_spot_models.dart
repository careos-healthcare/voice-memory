import 'package:archiveme_mobile/features/insights/insight_evidence.dart';

class BlindSpotInsight {
  const BlindSpotInsight({
    required this.id,
    required this.title,
    required this.summary,
    required this.confidence,
    required this.evidenceCount,
    required this.supportingEvidence,
    required this.metricLabel,
    required this.metricValue,
  });

  final String id;
  final String title;
  final String summary;
  final int confidence;
  final int evidenceCount;
  final List<InsightEvidenceLine> supportingEvidence;
  final String metricLabel;
  final String metricValue;
}