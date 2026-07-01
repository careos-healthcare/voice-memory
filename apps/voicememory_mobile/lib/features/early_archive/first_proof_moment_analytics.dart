import 'early_archive_proof_analytics.dart';

/// Safe metadata analytics for the first proof moment — no journal text.
abstract final class FirstProofMomentAnalytics {
  FirstProofMomentAnalytics._();

  static void seen({
    required int entryCount,
    required int phraseCount,
    required bool hasStrongEvidence,
  }) {
    EarlyArchiveProofAnalytics.firstProofMomentSeen(
      entryCount: entryCount,
      phraseCount: phraseCount,
      hasStrongEvidence: hasStrongEvidence,
    );
  }
}
