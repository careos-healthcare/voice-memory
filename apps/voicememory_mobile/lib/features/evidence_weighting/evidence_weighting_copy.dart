import 'evidence_weighting_model.dart';

/// User-facing copy for evidence freshness weighting — explanation only.
abstract final class EvidenceWeightingCopy {
  EvidenceWeightingCopy._();

  static const title = 'Not all evidence counts the same.';

  static const body =
      'ArchiveMe weighs recent and repeated moments more heavily. '
      'Older evidence becomes lighter unless it keeps returning.';

  static const footer = 'Your past is context, not a verdict.';

  static const differentiationLine =
      'ChatGPT can respond to what you say now. ArchiveMe can show whether '
      'older evidence is still active, fading, or no longer important.';

  static const List<String> all = [
    title,
    body,
    footer,
    differentiationLine,
    labelFresh,
    labelRepeated,
    labelFading,
    labelSoftened,
    labelOldSignal,
    labelNeedsFreshProof,
    explanationFresh,
    explanationRepeated,
    explanationFading,
    explanationSoftened,
    explanationOldSignal,
    explanationNeedsFreshProof,
  ];

  static const labelFresh = 'Fresh';
  static const labelRepeated = 'Repeated';
  static const labelFading = 'Fading';
  static const labelSoftened = 'Softened';
  static const labelOldSignal = 'Old signal';
  static const labelNeedsFreshProof = 'Needs fresh proof';

  static const explanationFresh = 'Appeared recently.';
  static const explanationRepeated =
      'Appeared across more than one saved moment.';
  static const explanationFading =
      'Has not appeared recently, so ArchiveMe treats it more lightly.';
  static const explanationSoftened =
      'Still appears, but with less urgency or force.';
  static const explanationOldSignal =
      'Useful context, but not strong current proof.';
  static const explanationNeedsFreshProof =
      'ArchiveMe should wait for newer evidence before treating this as current.';

  static String labelFor(EvidenceWeightState state) => switch (state) {
    EvidenceWeightState.fresh => labelFresh,
    EvidenceWeightState.repeated => labelRepeated,
    EvidenceWeightState.fading => labelFading,
    EvidenceWeightState.softened => labelSoftened,
    EvidenceWeightState.oldSignal => labelOldSignal,
    EvidenceWeightState.needsFreshProof => labelNeedsFreshProof,
  };

  static String explanationFor(EvidenceWeightState state) => switch (state) {
    EvidenceWeightState.fresh => explanationFresh,
    EvidenceWeightState.repeated => explanationRepeated,
    EvidenceWeightState.fading => explanationFading,
    EvidenceWeightState.softened => explanationSoftened,
    EvidenceWeightState.oldSignal => explanationOldSignal,
    EvidenceWeightState.needsFreshProof => explanationNeedsFreshProof,
  };
}
