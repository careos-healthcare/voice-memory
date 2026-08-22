import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';

/// Builds the structural analytics payload for one admission attempt.
///
/// It is a pure function so the payload shape can be asserted directly in tests
/// rather than inferred from whatever a provider happened to receive. Every
/// value is a band or a closed-set token: there is no code path here that can
/// read a transcript, a quote, a statement, an entry id, or a fingerprint.
class ProofAdmissionAnalytics {
  const ProofAdmissionAnalytics._();

  static const String eventName = 'proof_admission_result';

  static Map<String, Object> payload({
    required ProofAdmissionResult result,
    required int distinctSourceCount,
    required int contradictionCount,
    required Duration duration,
    int verifierVersion = 1,
    int scorerVersion = 1,
    int configVersion = 1,
  }) => {
    'admission_result': _token(result.outcome.name),
    if (result is ProofNotAdmitted) 'rejection_reason': _token(result.reason),
    if (result is ProofAdmitted)
      'confidence_band': result.proof.confidenceBand.name,
    'source_count_band': countBand(distinctSourceCount),
    'contradiction_count_band': countBand(contradictionCount),
    'duration_band': durationBand(duration),
    'verifier_version': verifierVersion,
    'scorer_version': scorerVersion,
    'config_version': configVersion,
    'eligibility_policy_version': EvidenceEligibilityPolicy.policyVersion,
  };

  /// Counts are banded so a value can never single out one archive.
  static String countBand(int count) {
    if (count <= 0) return 'none';
    if (count == 1) return 'one';
    if (count <= 3) return 'few';
    if (count <= 9) return 'several';
    return 'many';
  }

  /// Durations are banded rather than reported raw, because a precise timing is
  /// a function of the content that produced it.
  static String durationBand(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms < 50) return 'under_50ms';
    if (ms < 250) return 'under_250ms';
    if (ms < 1000) return 'under_1s';
    if (ms < 5000) return 'under_5s';
    return 'over_5s';
  }

  /// Folds a camelCase enum name or a reason string into the id shape the
  /// analytics guard accepts, so a token can never arrive as free text.
  static String _token(String raw) {
    final snake = raw
        .replaceAllMapped(
          RegExp('([a-z0-9])([A-Z])'),
          (match) => '${match[1]}_${match[2]}',
        )
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_]'), '_')
        .replaceAll(RegExp('_+'), '_');
    final trimmed = snake.replaceAll(RegExp(r'^_|_$'), '');
    if (trimmed.isEmpty) return 'unknown';
    return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
  }
}