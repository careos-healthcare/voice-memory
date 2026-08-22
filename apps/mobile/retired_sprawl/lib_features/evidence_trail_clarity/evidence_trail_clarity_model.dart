import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';

enum EvidenceTrailClarityFeedbackOption { yes, notYet, needMoreProof }

extension EvidenceTrailClarityFeedbackOptionAnalytics
    on EvidenceTrailClarityFeedbackOption {
  String get analyticsValue => switch (this) {
    EvidenceTrailClarityFeedbackOption.yes => 'yes',
    EvidenceTrailClarityFeedbackOption.notYet => 'not_yet',
    EvidenceTrailClarityFeedbackOption.needMoreProof => 'need_more_proof',
  };
}

class EvidenceTrailClarityTimelineRow {
  const EvidenceTrailClarityTimelineRow({
    required this.label,
    required this.detail,
  });

  final String label;
  final String detail;
}

class EvidenceTrailClarityResult {
  const EvidenceTrailClarityResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.timelineRows,
    required this.supportLine,
    required this.primaryCta,
    required this.secondaryCta,
    required this.feedbackPrompt,
    required this.source,
    required this.entryCount,
    required this.hasUsefulProof,
    required this.confidenceLevel,
    required this.activeRepairMode,
  });

  static const hidden = EvidenceTrailClarityResult(
    shouldShow: false,
    title: '',
    body: '',
    timelineRows: [],
    supportLine: '',
    primaryCta: '',
    secondaryCta: '',
    feedbackPrompt: '',
    source: '',
    entryCount: 0,
    hasUsefulProof: false,
    confidenceLevel: ProofConfidenceLevel.watchOnly,
    activeRepairMode: '',
  );

  final bool shouldShow;
  final String title;
  final String body;
  final List<EvidenceTrailClarityTimelineRow> timelineRows;
  final String supportLine;
  final String primaryCta;
  final String secondaryCta;
  final String feedbackPrompt;
  final String source;
  final int entryCount;
  final bool hasUsefulProof;
  final ProofConfidenceLevel confidenceLevel;
  final String activeRepairMode;
}