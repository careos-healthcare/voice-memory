import 'pro_moment_timing_audit_v2_copy.dart';

enum ProMomentTimingAuditV2Status {
  ready,
  watch,
  blocked;

  String get label => switch (this) {
    ProMomentTimingAuditV2Status.ready =>
      ProMomentTimingAuditV2Copy.statusReady,
    ProMomentTimingAuditV2Status.watch =>
      ProMomentTimingAuditV2Copy.statusWatch,
    ProMomentTimingAuditV2Status.blocked =>
      ProMomentTimingAuditV2Copy.statusBlocked,
  };
}

enum ProMomentTimingAuditV2CheckId {
  neverBeforeFirstProof,
  afterUsefulProof,
  afterStrongProof,
  afterFreshReturn,
  afterCorrectionRelevant,
  blockedTooVague,
  blockedNotRelevant,
  alreadyKnewNeedsDelta,
  notHiddenByGuidance,
  paywallSourceProofConnected,
  paywallCopyProofConnected,
  oneProCardPerSurface,
}

enum ProMomentTimingAuditV2DiagnosisId {
  tooEarly,
  tooHidden,
  wrongSource,
  tooCluttered,
  correct,
}

class ProMomentTimingAuditV2Check {
  const ProMomentTimingAuditV2Check({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final ProMomentTimingAuditV2CheckId id;
  final String label;
  final ProMomentTimingAuditV2Status status;
  final String detailLabel;
}

class ProMomentTimingAuditV2Diagnosis {
  const ProMomentTimingAuditV2Diagnosis({
    required this.id,
    required this.title,
  });

  final ProMomentTimingAuditV2DiagnosisId id;
  final String title;
}

class ProMomentTimingAuditV2Snapshot {
  const ProMomentTimingAuditV2Snapshot({
    required this.title,
    required this.subtitle,
    required this.checks,
    required this.diagnoses,
    required this.readyCount,
    required this.blockedCount,
  });

  final String title;
  final String subtitle;
  final List<ProMomentTimingAuditV2Check> checks;
  final List<ProMomentTimingAuditV2Diagnosis> diagnoses;
  final int readyCount;
  final int blockedCount;

  List<String> get allDisplayedText => [
    title,
    subtitle,
    for (final check in checks) ...[
      check.label,
      check.detailLabel,
      check.status.label,
    ],
    for (final diagnosis in diagnoses) diagnosis.title,
    ProMomentTimingAuditV2Copy.localNote,
  ];
}
