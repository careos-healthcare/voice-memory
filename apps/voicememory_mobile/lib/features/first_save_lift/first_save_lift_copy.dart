/// Zero-entry first save lift copy — no journaling language.
abstract final class FirstSaveLiftCopy {
  FirstSaveLiftCopy._();

  static const title = 'Save one small moment';
  static const body =
      'One sentence is enough. ArchiveMe needs a first real moment before it can show what returns.';
  static const primaryCta = 'Type one sentence';
  static const secondaryCta = 'Record instead';

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
