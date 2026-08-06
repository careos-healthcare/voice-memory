/// First-session capture lift copy — metadata-safe, no journal text.
abstract final class FirstSessionLiftCopy {
  FirstSessionLiftCopy._();

  static const title = 'Start with one sentence';
  static const body =
      'Do not journal. Save one moment that felt familiar, unfinished, or hard to let go of.';
  static const primaryCta = 'Type one sentence';
  static const secondaryCta = 'Use voice instead';
  static const microcopy =
      'ArchiveMe only needs a real first moment. You can come back later if it repeats.';

  static const exampleKeptCheckingAgain = 'I kept checking again';
  static const exampleAvoidedReplying = 'I avoided replying';
  static const exampleWantedControl = 'I wanted control';
  static const exampleFeltFamiliar = 'This felt familiar';

  static const exampleOrder = [
    FirstSessionLiftChipId.keptCheckingAgain,
    FirstSessionLiftChipId.avoidedReplying,
    FirstSessionLiftChipId.wantedControl,
    FirstSessionLiftChipId.feltFamiliar,
  ];

  static String exampleTextFor(FirstSessionLiftChipId id) => switch (id) {
    FirstSessionLiftChipId.keptCheckingAgain => exampleKeptCheckingAgain,
    FirstSessionLiftChipId.avoidedReplying => exampleAvoidedReplying,
    FirstSessionLiftChipId.wantedControl => exampleWantedControl,
    FirstSessionLiftChipId.feltFamiliar => exampleFeltFamiliar,
  };

  static String chipAnalyticsId(FirstSessionLiftChipId id) => switch (id) {
    FirstSessionLiftChipId.keptCheckingAgain => 'kept_checking_again',
    FirstSessionLiftChipId.avoidedReplying => 'avoided_replying',
    FirstSessionLiftChipId.wantedControl => 'wanted_control',
    FirstSessionLiftChipId.feltFamiliar => 'felt_familiar',
  };

  static const diagnosisFixFirstSessionCapture = 'Fix first-session capture';
  static const diagnosisFixProUnderstanding = 'Fix Pro understanding';
  static const diagnosisReadyForMoreTesters = 'Ready for more testers';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield primaryCta;
    yield secondaryCta;
    yield microcopy;
    yield exampleKeptCheckingAgain;
    yield exampleAvoidedReplying;
    yield exampleWantedControl;
    yield exampleFeltFamiliar;
    yield diagnosisFixFirstSessionCapture;
    yield diagnosisFixProUnderstanding;
    yield diagnosisReadyForMoreTesters;
  }
}

enum FirstSessionLiftChipId {
  keptCheckingAgain,
  avoidedReplying,
  wantedControl,
  feltFamiliar,
}

enum FirstSessionLiftActionType {
  typeOneSentence,
  useVoiceInstead,
  chipTapped;

  String get analyticsValue => switch (this) {
    FirstSessionLiftActionType.typeOneSentence => 'type_one_sentence',
    FirstSessionLiftActionType.useVoiceInstead => 'use_voice_instead',
    FirstSessionLiftActionType.chipTapped => 'chip_tapped',
  };
}
