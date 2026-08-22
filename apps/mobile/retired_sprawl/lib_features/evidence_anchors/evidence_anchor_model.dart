import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_copy.dart';

enum EvidenceAnchorType {
  repeat,
  change,
  softening,
  strengthening,
  helped,
  avoided,
  current,
  fading,
  corrected,
  freshReturn,
  unknown,
}

extension EvidenceAnchorTypeAnalytics on EvidenceAnchorType {
  String get analyticsValue => switch (this) {
    EvidenceAnchorType.repeat => 'repeat',
    EvidenceAnchorType.change => 'change',
    EvidenceAnchorType.softening => 'softening',
    EvidenceAnchorType.strengthening => 'strengthening',
    EvidenceAnchorType.helped => 'helped',
    EvidenceAnchorType.avoided => 'avoided',
    EvidenceAnchorType.current => 'current',
    EvidenceAnchorType.fading => 'fading',
    EvidenceAnchorType.corrected => 'corrected',
    EvidenceAnchorType.freshReturn => 'fresh_return',
    EvidenceAnchorType.unknown => 'unknown',
  };

  String get label => switch (this) {
    EvidenceAnchorType.repeat => EvidenceAnchorCopy.labelRepeat,
    EvidenceAnchorType.change => EvidenceAnchorCopy.labelChange,
    EvidenceAnchorType.softening => EvidenceAnchorCopy.labelSoftening,
    EvidenceAnchorType.strengthening => EvidenceAnchorCopy.labelStrengthening,
    EvidenceAnchorType.helped => EvidenceAnchorCopy.labelHelped,
    EvidenceAnchorType.avoided => EvidenceAnchorCopy.labelAvoided,
    EvidenceAnchorType.current => EvidenceAnchorCopy.labelCurrent,
    EvidenceAnchorType.fading => EvidenceAnchorCopy.labelFading,
    EvidenceAnchorType.corrected => EvidenceAnchorCopy.labelCorrected,
    EvidenceAnchorType.freshReturn => EvidenceAnchorCopy.labelFreshReturn,
    EvidenceAnchorType.unknown => EvidenceAnchorCopy.labelUnknown,
  };
}

class EvidenceAnchor {
  const EvidenceAnchor({
    required this.id,
    required this.type,
    required this.label,
    required this.safeSummary,
    required this.strength,
    required this.recencyWeight,
    required this.sourceCount,
    required this.isUserCorrected,
    required this.isFreshReturn,
    required this.isSafeForDisplay,
  });

  final String id;
  final EvidenceAnchorType type;
  final String label;
  final String safeSummary;
  final double strength;
  final double recencyWeight;
  final int sourceCount;
  final bool isUserCorrected;
  final bool isFreshReturn;
  final bool isSafeForDisplay;
}

class EvidenceAnchorExtractionResult {
  const EvidenceAnchorExtractionResult({
    required this.shouldExtract,
    required this.entryCount,
    required this.source,
    required this.anchors,
    required this.safeSummaries,
    required this.usesFallback,
    required this.hasSafeAnchor,
    required this.hasRecentAnchor,
    required this.hasCorrectionAnchor,
    required this.hasChangeAnchor,
  });

  factory EvidenceAnchorExtractionResult.hidden({
    required String source,
    required int entryCount,
  }) => EvidenceAnchorExtractionResult(
    shouldExtract: false,
    entryCount: entryCount,
    source: source,
    anchors: const [],
    safeSummaries: const [],
    usesFallback: false,
    hasSafeAnchor: false,
    hasRecentAnchor: false,
    hasCorrectionAnchor: false,
    hasChangeAnchor: false,
  );

  final bool shouldExtract;
  final int entryCount;
  final String source;
  final List<EvidenceAnchor> anchors;
  final List<String> safeSummaries;
  final bool usesFallback;
  final bool hasSafeAnchor;
  final bool hasRecentAnchor;
  final bool hasCorrectionAnchor;
  final bool hasChangeAnchor;

  List<String> get anchorTypeAnalyticsValues =>
      anchors.map((anchor) => anchor.type.analyticsValue).toList();
}