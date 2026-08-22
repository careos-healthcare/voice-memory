import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle_copy.dart';

enum ProofSelectionPrincipleRule {
  clearestSafeRepeatNow,
  notNecessarilyMostImportant,
  confirmableOrCorrectable,
  notRankedList,
  notDiagnosisCoachingOrAdvice,
}

extension ProofSelectionPrincipleRuleLabel on ProofSelectionPrincipleRule {
  String get label => switch (this) {
    ProofSelectionPrincipleRule.clearestSafeRepeatNow =>
      'Clearest safe repeat right now',
    ProofSelectionPrincipleRule.notNecessarilyMostImportant =>
      'Not necessarily the most important thing',
    ProofSelectionPrincipleRule.confirmableOrCorrectable =>
      'Confirmable or correctable by the user',
    ProofSelectionPrincipleRule.notRankedList => 'Not a ranked list',
    ProofSelectionPrincipleRule.notDiagnosisCoachingOrAdvice =>
      'Not a diagnosis, coaching insight, or advice',
  };
}

/// Decision helpers that reinforce proof selection over ranking.
abstract final class ProofSelectionPrinciple {
  ProofSelectionPrinciple._();

  static const List<ProofSelectionPrincipleRule> rules = ProofSelectionPrincipleRule.values;

  static ProofSelectionPrincipleSnapshot snapshot() =>
      const ProofSelectionPrincipleSnapshot(
        headline: ProofSelectionPrincipleCopy.headline,
        body: ProofSelectionPrincipleCopy.body,
        guardrail: ProofSelectionPrincipleCopy.guardrail,
        decisionLabel: ProofSelectionPrincipleCopy.decisionLabel,
        rules: rules,
      );

  static bool allowsRankingUi() => false;

  static bool allowsImportanceScoring() => false;

  static bool allowsRankedLists() => false;

  static bool detailCopyAlignsWithPrinciple() =>
      ProofDetailRepairCopy.whyThisOneLine ==
          ProofSelectionPrincipleCopy.whyThisOneLine &&
      ProofDetailRepairCopy.notRankingOrMostImportantLine ==
          ProofSelectionPrincipleCopy.notRankingOrMostImportantLine &&
      ProofDetailRepairCopy.correctionLine ==
          ProofSelectionPrincipleCopy.correctionLine;

  static bool copyPassesGuard(String text) {
    final lower = text.toLowerCase();
    for (final phrase in ProofSelectionPrincipleCopy.bannedPhrases) {
      if (lower.contains(phrase)) return false;
    }
    return true;
  }
}

class ProofSelectionPrincipleSnapshot {
  const ProofSelectionPrincipleSnapshot({
    required this.headline,
    required this.body,
    required this.guardrail,
    required this.decisionLabel,
    required this.rules,
  });

  final String headline;
  final String body;
  final String guardrail;
  final String decisionLabel;
  final List<ProofSelectionPrincipleRule> rules;
}