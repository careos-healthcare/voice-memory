import 'package:archiveme_mobile/features/proof_relevance_repair/proof_relevance_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle_copy.dart';

/// Optional proof detail copy — safe behaviour phrase only, no journal text.
abstract final class ProofDetailRepairCopy {
  ProofDetailRepairCopy._();

  static const ctaMoreDetail = 'More detail';
  static const ctaWhyThis = 'Why this?';

  static const title = 'Why this may matter';

  static const similarMomentsLead =
      'This appeared because similar saved moments mention:';

  static const String whyThisOneLine = ProofSelectionPrincipleCopy.whyThisOneLine;

  static const String notRankingOrMostImportantLine =
      ProofSelectionPrincipleCopy.notRankingOrMostImportantLine;

  static const whyItMayMatterLine =
      'Why it may matter: it showed up more than once, and the wording was '
      'specific enough to compare safely.';

  static const String correctionLine = ProofSelectionPrincipleCopy.correctionLine;

  static const bannedDetailPhrases = [
    'ranked list',
    'most important pattern',
    'the key issue',
    'you should focus on',
    'this means',
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
    return '$similarMomentsLead $formatted $whyThisOneLine '
        '$notRankingOrMostImportantLine $whyItMayMatterLine $correctionLine';
  }

  static Iterable<String> allVisibleStrings() sync* {
    yield ctaMoreDetail;
    yield ctaWhyThis;
    yield title;
    yield similarMomentsLead;
    yield whyThisOneLine;
    yield notRankingOrMostImportantLine;
    yield whyItMayMatterLine;
    yield correctionLine;
    yield composeBody('said yes when I had no capacity');
  }
}