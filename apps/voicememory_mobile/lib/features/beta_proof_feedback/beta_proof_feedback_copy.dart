import 'beta_proof_feedback_model.dart';

import '../proof_relevance_repair/proof_relevance_repair_copy.dart';

/// Beta-only proof feedback copy — product learning, not therapy.
abstract final class BetaProofFeedbackCopy {
  BetaProofFeedbackCopy._();

  static const question = ProofRelevanceRepairCopy.relevanceQuestion;

  static const answerUseful = ProofRelevanceRepairCopy.answerYes;
  static const answerTooVague = ProofRelevanceRepairCopy.answerTooVague;
  static const answerAlreadyKnew = 'Already knew this';
  static const answerNotRelevant = ProofRelevanceRepairCopy.answerNotRelevant;

  static const thanksMessage =
      'Thanks — this helps tune what ArchiveMe shows next.';

  static String labelFor(BetaProofFeedbackType type) =>
      ProofRelevanceRepairCopy.labelFor(type);

  static String responseFor(BetaProofFeedbackType type) =>
      ProofRelevanceRepairCopy.responseFor(type);

  static List<String> allVisibleStrings() => [
    question,
    answerUseful,
    answerTooVague,
    answerAlreadyKnew,
    answerNotRelevant,
    thanksMessage,
    ...ProofRelevanceRepairCopy.allVisibleStrings(),
  ];
}
