import 'beta_proof_feedback_model.dart';

/// Beta-only proof feedback copy — product learning, not therapy.
abstract final class BetaProofFeedbackCopy {
  BetaProofFeedbackCopy._();

  static const question = 'Was this useful?';

  static const answerUseful = 'Useful';
  static const answerTooVague = 'Too vague';
  static const answerAlreadyKnew = 'Already knew this';
  static const answerNotRelevant = 'Not relevant';

  static const thanksMessage =
      'Thanks — this helps tune what ArchiveMe shows next.';

  static String labelFor(BetaProofFeedbackType type) => switch (type) {
        BetaProofFeedbackType.useful => answerUseful,
        BetaProofFeedbackType.tooVague => answerTooVague,
        BetaProofFeedbackType.alreadyKnew => answerAlreadyKnew,
        BetaProofFeedbackType.notRelevant => answerNotRelevant,
      };

  static List<String> allVisibleStrings() => [
        question,
        answerUseful,
        answerTooVague,
        answerAlreadyKnew,
        answerNotRelevant,
        thanksMessage,
      ];
}
