import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';

/// Zero-entry first save lift copy — no journaling language.
abstract final class FirstSaveLiftCopy {
  FirstSaveLiftCopy._();

  static const title = RevenueLiftExperimentV2Copy.firstSaveTitle;
  static const body = RevenueLiftExperimentV2Copy.firstSaveBody;
  static const primaryCta = RevenueLiftExperimentV2Copy.firstSavePrimaryCta;
  static const secondaryCta = RevenueLiftExperimentV2Copy.firstSaveSecondaryCta;

  static const exampleKeptCheckingAgain = 'I kept checking again';
  static const exampleAvoidedMessage = 'I avoided the message';
  static const exampleFeltFamiliar = 'This felt familiar';
  static const exampleWantedControl = 'I wanted control';

  static const exampleOrder = <FirstSaveLiftExampleId>[
    FirstSaveLiftExampleId.keptCheckingAgain,
    FirstSaveLiftExampleId.avoidedMessage,
    FirstSaveLiftExampleId.feltFamiliar,
    FirstSaveLiftExampleId.wantedControl,
  ];

  static String exampleTextFor(FirstSaveLiftExampleId id) => switch (id) {
        FirstSaveLiftExampleId.keptCheckingAgain => exampleKeptCheckingAgain,
        FirstSaveLiftExampleId.avoidedMessage => exampleAvoidedMessage,
        FirstSaveLiftExampleId.feltFamiliar => exampleFeltFamiliar,
        FirstSaveLiftExampleId.wantedControl => exampleWantedControl,
      };

  static String exampleAnalyticsId(FirstSaveLiftExampleId id) => switch (id) {
        FirstSaveLiftExampleId.keptCheckingAgain => 'kept_checking_again',
        FirstSaveLiftExampleId.avoidedMessage => 'avoided_message',
        FirstSaveLiftExampleId.feltFamiliar => 'felt_familiar',
        FirstSaveLiftExampleId.wantedControl => 'wanted_control',
      };
}

enum FirstSaveLiftExampleId {
  keptCheckingAgain,
  avoidedMessage,
  feltFamiliar,
  wantedControl,
}

enum FirstSaveLiftActionType {
  typeOneSentence,
  recordInstead,
  exampleTapped,
}

extension FirstSaveLiftActionTypeStorage on FirstSaveLiftActionType {
  String get analyticsValue => switch (this) {
        FirstSaveLiftActionType.typeOneSentence => 'type_one_sentence',
        FirstSaveLiftActionType.recordInstead => 'record_instead',
        FirstSaveLiftActionType.exampleTapped => 'example_tapped',
      };
}
