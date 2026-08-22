/// Versioned, explicit thresholds for the focused-beta evidence contract.
///
/// Safe by default: one moment never unlocks pattern or change claims.
abstract final class EvidenceEligibilityPolicyConfig {
  EvidenceEligibilityPolicyConfig._();

  static const String schemaName = 'archiveme.evidence_eligibility_policy';
  static const int policyVersion = 1;

  /// Minimum admitted moments before any relationship copy may appear.
  static const int relatedMomentsMinimum = 2;

  /// Minimum admitted moments before a possible-pattern candidate may form.
  static const int possiblePatternMinimum = 3;

  /// Minimum admitted moments before Changes surfaces may appear.
  static const int changesSurfaceMinimum = 3;

  /// Minimum calendar separation between supporting moments for a pattern.
  static const Duration minimumPatternTimeSeparation = Duration(hours: 12);

  /// Minimum separation between earlier and recent evidence for a change claim.
  static const Duration minimumChangeTimeSeparation = Duration(days: 1);

  /// Minimum distinct admitted sources required per claim kind at admission time.
  static const Map<String, int> admissionSourceMinimums = {
    'mainObservation': 1,
    'nextAction': 1,
    'repeated': 2,
    'directionOfChange': 2,
    'frequency': 3,
    'trend': 3,
    'strength': 4,
    'causalRelationship': 999,
  };
}
