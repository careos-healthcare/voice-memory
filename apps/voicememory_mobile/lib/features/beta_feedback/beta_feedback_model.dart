import 'beta_feedback_copy.dart';

/// Structured beta feedback option — v1 sheet only.
enum BetaFeedbackOptionType {
  confused,
  useful,
  wrong,
  wouldPay,
  wouldNotPayYet,
  notDifferentFromChat,
  other;

  String get label => switch (this) {
        BetaFeedbackOptionType.confused => BetaFeedbackCopy.optionConfused,
        BetaFeedbackOptionType.useful => BetaFeedbackCopy.optionUseful,
        BetaFeedbackOptionType.wrong => BetaFeedbackCopy.optionWrong,
        BetaFeedbackOptionType.wouldPay => BetaFeedbackCopy.optionWouldPay,
        BetaFeedbackOptionType.wouldNotPayYet =>
          BetaFeedbackCopy.optionWouldNotPayYet,
        BetaFeedbackOptionType.notDifferentFromChat =>
          BetaFeedbackCopy.optionNotDifferentFromChat,
        BetaFeedbackOptionType.other => BetaFeedbackCopy.optionOther,
      };

  String get analyticsKey => switch (this) {
        BetaFeedbackOptionType.confused => 'confused',
        BetaFeedbackOptionType.useful => 'useful',
        BetaFeedbackOptionType.wrong => 'wrong',
        BetaFeedbackOptionType.wouldPay => 'would_pay',
        BetaFeedbackOptionType.wouldNotPayYet => 'would_not_pay_yet',
        BetaFeedbackOptionType.notDifferentFromChat => 'not_different_from_chat',
        BetaFeedbackOptionType.other => 'other',
      };
}

/// User submission for beta feedback v1 — explicit fields only.
class BetaFeedbackSubmission {
  const BetaFeedbackSubmission({
    required this.source,
    required this.option,
    required this.entryCount,
    required this.appVersion,
    this.note,
  });

  final String source;
  final BetaFeedbackOptionType option;
  final int entryCount;
  final String appVersion;
  final String? note;
}

enum BetaFeedbackSubmitOutcome {
  emailOpened,
  copiedFallback,
  cancelled,
  failed,
}
