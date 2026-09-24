/// Rollback-guard copy when caution would hide useful proof.
abstract final class ProofCautionGuardCopy {
  ProofCautionGuardCopy._();

  static const upgradeBody =
      'ArchiveMe has enough to treat this as useful, but it is still watching for fresher proof.';

  static const bannedMedicalTerms = <String>[
    'therapy',
    'diagnosis',
    'treatment',
    'medical advice',
    'clinical',
  ];

  static bool passesMedicalGuard(String copy) {
    final lower = copy.trim().toLowerCase();
    if (lower.isEmpty) return true;
    for (final term in bannedMedicalTerms) {
      if (lower.contains(term)) return false;
    }
    return true;
  }
}
