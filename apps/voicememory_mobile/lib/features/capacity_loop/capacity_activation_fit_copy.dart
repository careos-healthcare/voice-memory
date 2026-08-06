import 'capacity_activation_fit_models.dart';

/// Copy for capacity activation fit check — safe, non-clinical language.
abstract final class CapacityActivationFitCopy {
  CapacityActivationFitCopy._();

  static const cardTitle = 'Does this feel accurate?';
  static const cardBody =
      'You saved 3 yes moments. Does this loop fit what you noticed?';

  static const saveFeedbackCta = 'Save feedback';
  static const skipCta = 'Skip for now';

  static const betaTaskLine =
      'After 3 yes moments, answer whether the loop feels accurate.';

  static String labelForResponse(String responseId) => switch (responseId) {
    CapacityActivationFitResponseIds.fits => 'Yes, this fits',
    CapacityActivationFitResponseIds.partly => 'Partly',
    CapacityActivationFitResponseIds.notYet => 'Not yet',
    CapacityActivationFitResponseIds.tooEarly => 'Too early to tell',
    _ => '',
  };

  static String shortLabelForResponse(String responseId) =>
      switch (responseId) {
        CapacityActivationFitResponseIds.fits => 'fits',
        CapacityActivationFitResponseIds.partly => 'partly',
        CapacityActivationFitResponseIds.notYet => 'not yet',
        CapacityActivationFitResponseIds.tooEarly => 'too early',
        _ => '',
      };

  static String loopMarkedLine(String responseId) =>
      'You marked this loop as: ${shortLabelForResponse(responseId)}.';

  static List<String> allVisibleStrings() => [
    cardTitle,
    cardBody,
    saveFeedbackCta,
    skipCta,
    betaTaskLine,
    ...CapacityActivationFitResponseIds.all.map(labelForResponse),
    loopMarkedLine(CapacityActivationFitResponseIds.fits),
    loopMarkedLine(CapacityActivationFitResponseIds.partly),
    loopMarkedLine(CapacityActivationFitResponseIds.notYet),
    loopMarkedLine(CapacityActivationFitResponseIds.tooEarly),
  ];
}
