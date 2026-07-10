import '../proof_relevance_repair/proof_relevance_repair_copy.dart';

/// Optional proof detail copy — safe behaviour phrase only, no journal text.
abstract final class ProofDetailRepairCopy {
  ProofDetailRepairCopy._();

  static const ctaMoreDetail = 'More detail';
  static const ctaWhyThis = 'Why this?';

  static const title = 'Why ArchiveMe noticed this';

  static const similarMomentsLead =
      'This appeared because similar saved moments mention:';

  static const specificEnoughLine =
      'ArchiveMe is treating it as useful proof only because the wording is '
      'specific enough.';

  static const importanceLine =
      'This may be worth watching because it has appeared more than once.';

  static const correctionLine =
      'If this feels wrong, mark it Too vague or Not relevant.';

  static const bannedDetailPhrases = [
    'important idea',
    'this is your pattern',
    'you should',
    'you need to',
    'therapy',
    'diagnosis',
    'coach',
    'coaching',
  ];

  static String formatBehaviorPhrase(String phrase) =>
      ProofRelevanceRepairCopy.formatBehaviorPhrase(phrase);

  static String composeBody(String behaviorPhrase) {
    final formatted = formatBehaviorPhrase(behaviorPhrase);
    return '$similarMomentsLead $formatted $specificEnoughLine '
        '$importanceLine $correctionLine';
  }

  static Iterable<String> allVisibleStrings() sync* {
    yield ctaMoreDetail;
    yield ctaWhyThis;
    yield title;
    yield similarMomentsLead;
    yield specificEnoughLine;
    yield importanceLine;
    yield correctionLine;
    yield composeBody('said yes when I had no capacity');
  }
}
