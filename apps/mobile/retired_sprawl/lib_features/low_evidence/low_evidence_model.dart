/// Which low-evidence reassurance state applies.
enum LowEvidenceStateKind {
  oneRealEntry,
  twoUnrelatedRealEntries,
  twoRelatedNotEnough,
  genericTestOnly,
  quietDayOnly,
}

/// User-facing low-evidence guidance for one surface.
class LowEvidenceGuidance {
  const LowEvidenceGuidance({
    required this.kind,
    required this.title,
    required this.body,
    this.claimsRepeatForming = false,
  });

  final LowEvidenceStateKind kind;
  final String title;
  final String body;

  /// True only when grounded repeat exists but first proof is not unlocked.
  final bool claimsRepeatForming;
}