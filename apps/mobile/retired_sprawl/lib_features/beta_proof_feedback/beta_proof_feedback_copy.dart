import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';

import 'package:archiveme_mobile/features/proof_relevance_repair/proof_relevance_repair_copy.dart';

/// Beta-only proof feedback copy — product learning, not therapy.
abstract final class BetaProofFeedbackCopy {
  BetaProofFeedbackCopy._();

  static const String question = ProofRelevanceRepairCopy.relevanceQuestion;

  static const String answerUseful = ProofRelevanceRepairCopy.answerYes;
  static const String answerTooVague = ProofRelevanceRepairCopy.answerTooVague;
  static const answerAlreadyKnew = 'Already knew this';
  static const String answerNotRelevant = ProofRelevanceRepairCopy.answerNotRelevant;

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