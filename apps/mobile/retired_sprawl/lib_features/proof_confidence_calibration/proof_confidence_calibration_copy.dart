import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';

/// Safe proof copy calibrated to evidence strength — no private text.
abstract final class ProofConfidenceCalibrationCopy {
  ProofConfidenceCalibrationCopy._();

  static const watchOnly = 'ArchiveMe is watching this for now.';

  static const emerging = 'This may be starting to repeat.';

  static const useful = 'This has returned in more than one saved moment.';

  static const strong = 'This has a clearer timeline now.';

  static const corrected =
      'You corrected this, so ArchiveMe is treating it lightly.';

  static const freshReturn = 'This returned after you marked it as background.';

  static const changeDeltaLead =
      'Something changed between these saved moments.';

  static const helpedSoftenedLead = 'Recent evidence looks lighter or helped.';

  static const watchOnlySubtitle =
      'ArchiveMe is watching this lightly until the overlap is clearer.';

  static const firstProofPayoffEmerging =
      'ArchiveMe noticed the same thread across your saved moments.';

  static const returnAfterProofEmerging =
      'ArchiveMe has enough to start a timeline. The next useful moment is whether this returns or changes.';

  static const returnAfterProofStrong =
      'ArchiveMe has a clearer timeline now. The next useful moment is whether this returns or changes.';

  static const bannedIdentityClaims = [
    'you always',
    'you never',
    'this is who you are',
    'fixed identity',
  ];

  static const List<String> all = [
    watchOnly,
    emerging,
    useful,
    strong,
    corrected,
    freshReturn,
    changeDeltaLead,
    helpedSoftenedLead,
    watchOnlySubtitle,
    firstProofPayoffEmerging,
    returnAfterProofEmerging,
    returnAfterProofStrong,
  ];

  static String primaryFor(ProofConfidenceLevel level) => switch (level) {
    ProofConfidenceLevel.watchOnly => watchOnly,
    ProofConfidenceLevel.emerging => emerging,
    ProofConfidenceLevel.useful => useful,
    ProofConfidenceLevel.strong => strong,
    ProofConfidenceLevel.corrected => corrected,
    ProofConfidenceLevel.freshReturn => freshReturn,
  };

  static bool passesIdentityGuard(String copy) {
    final lower = copy.trim().toLowerCase();
    if (lower.isEmpty) return true;
    for (final banned in bannedIdentityClaims) {
      if (lower.contains(banned)) return false;
    }
    return true;
  }
}