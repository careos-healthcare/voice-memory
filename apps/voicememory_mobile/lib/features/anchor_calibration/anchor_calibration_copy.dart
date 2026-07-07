/// Copy for anchor calibration corrections — safe, no private text.
abstract final class AnchorCalibrationCopy {
  AnchorCalibrationCopy._();

  static const changeTrackingBody =
      'ArchiveMe is tracking whether this changes.';

  static const backgroundUnlessReturnBody =
      'ArchiveMe will treat this as background unless it returns.';

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
