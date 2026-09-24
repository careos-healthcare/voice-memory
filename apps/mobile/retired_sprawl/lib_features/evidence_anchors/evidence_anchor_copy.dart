/// Safe labels and fallback copy for evidence anchors — no private text.
abstract final class EvidenceAnchorCopy {
  EvidenceAnchorCopy._();

  static const fallbackSummary =
      'More than one saved moment pointed in the same direction.';

  static const labelRepeat = 'Repeat';
  static const labelChange = 'Change';
  static const labelSoftening = 'Softening';
  static const labelStrengthening = 'Strengthening';
  static const labelHelped = 'Helped';
  static const labelAvoided = 'Avoided';
  static const labelCurrent = 'Current';
  static const labelFading = 'Fading';
  static const labelCorrected = 'Corrected';
  static const labelFreshReturn = 'Fresh return';
  static const labelUnknown = 'Evidence';

  static const List<String> all = [
    fallbackSummary,
    labelRepeat,
    labelChange,
    labelSoftening,
    labelStrengthening,
    labelHelped,
    labelAvoided,
    labelCurrent,
    labelFading,
    labelCorrected,
    labelFreshReturn,
    labelUnknown,
  ];
}
