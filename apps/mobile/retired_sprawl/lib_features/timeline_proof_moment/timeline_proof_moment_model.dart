import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_model.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';

class TimelineProofMomentRow {
  const TimelineProofMomentRow({
    required this.label,
    this.detail,
    this.anchorType,
  });

  final String label;
  final String? detail;
  final EvidenceAnchorType? anchorType;
}

class TimelineProofMomentResult {
  const TimelineProofMomentResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasCorrection,
    required this.currentWeight,
    required this.rowCount,
    required this.title,
    required this.body,
    required this.rows,
    required this.currentWeightLine,
    required this.footer,
    required this.differentiationLine,
    required this.proLine,
    required this.compact,
    required this.evidenceAnchors,
    required this.hasSafeAnchor,
    required this.usesFallbackEvidenceLine,
    required this.patternMatchQuality,
    required this.proofConfidenceCalibration,
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasCorrection;
  final ArchiveTimelineSpineCurrentWeight currentWeight;
  final int rowCount;
  final String title;
  final String body;
  final List<TimelineProofMomentRow> rows;
  final String currentWeightLine;
  final String footer;
  final String differentiationLine;
  final String proLine;
  final bool compact;
  final List<String> evidenceAnchors;
  final bool hasSafeAnchor;
  final bool usesFallbackEvidenceLine;
  final PatternMatchQualityResult patternMatchQuality;
  final ProofConfidenceCalibrationResult proofConfidenceCalibration;
}