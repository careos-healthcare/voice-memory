import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'proof_relevance_repair_copy.dart';

/// Composes proof card copy from safe behaviour phrases and confidence level.
abstract final class ProofRelevanceRepairEngine {
  ProofRelevanceRepairEngine._();

  static String composeDisplayCopy({
    required ProofConfidenceLevel level,
    required String? behaviorPhrase,
    required bool hasSafeAnchor,
    required String? leadCopy,
    required String primaryCopy,
  }) {
    if (!_shouldUseRelevanceCopy(level: level, hasSafeAnchor: hasSafeAnchor)) {
      return _fallbackDisplayCopy(
        leadCopy: leadCopy,
        primaryCopy: primaryCopy,
      );
    }

    final phrase = behaviorPhrase?.trim();
    if (phrase == null || phrase.isEmpty) {
      return _fallbackDisplayCopy(
        leadCopy: leadCopy,
        primaryCopy: primaryCopy,
      );
    }

    final lead = leadFor(level: level);
    final formattedPhrase = ProofRelevanceRepairCopy.formatBehaviorPhrase(phrase);
    final whyLine = ProofRelevanceRepairCopy.whyAppearedLine;
    final prefix = leadCopy?.trim();
    if (prefix != null && prefix.isNotEmpty) {
      return '$prefix $lead $formattedPhrase $whyLine';
    }
    return '$lead $formattedPhrase $whyLine';
  }

  static String leadFor({required ProofConfidenceLevel level}) {
    return switch (level) {
      ProofConfidenceLevel.emerging => ProofRelevanceRepairCopy.softerLead,
      ProofConfidenceLevel.useful ||
      ProofConfidenceLevel.strong ||
      ProofConfidenceLevel.freshReturn =>
        ProofRelevanceRepairCopy.strongLead,
      _ => ProofRelevanceRepairCopy.softerLead,
    };
  }

  static bool _shouldUseRelevanceCopy({
    required ProofConfidenceLevel level,
    required bool hasSafeAnchor,
  }) =>
      hasSafeAnchor &&
      level != ProofConfidenceLevel.watchOnly &&
      level != ProofConfidenceLevel.corrected;

  static String _fallbackDisplayCopy({
    required String? leadCopy,
    required String primaryCopy,
  }) {
    final prefix = leadCopy?.trim();
    if (prefix == null || prefix.isEmpty) return primaryCopy;
    return '$prefix $primaryCopy';
  }
}
