/// Consumer copy for early behaviour-loop insights.
abstract class EarlyBehaviorLoopCopy {
  EarlyBehaviorLoopCopy._();

  static const String evidenceFallback =
      'This is based on two saved moments using similar language.';

  static const List<String> bannedTerms = [
    'voice memory',
    'voicememory',
    ' ai ',
    'artificial intelligence',
    'diagnosis',
    'diagnose',
    'disorder',
    'therapy',
    'therapist',
    'wellbeing',
  ];
}