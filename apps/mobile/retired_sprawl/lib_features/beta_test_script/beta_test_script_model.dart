/// Compact card phase on Record — inferred from local activity only.
enum BetaTestScriptCompactPhase {
  day1,
  day2,
  day3,
  firstProofReached,
  complete,
}

/// Progress row status for the testing screen summary.
enum BetaTestScriptRowStatus {
  notStarted,
  waiting,
  done,
  notReached,
  reached,
  notSent,
  sent,
}

/// One checklist day in the full tester script sheet.
class BetaTestScriptDayPlan {
  const BetaTestScriptDayPlan({
    required this.stepKey,
    required this.title,
    required this.body,
    required this.checklist,
  });

  final String stepKey;
  final String title;
  final String body;
  final List<String> checklist;
}

/// Progress summary for the Testing ArchiveMe screen.
class BetaTestScriptProgressSummary {
  const BetaTestScriptProgressSummary({
    required this.day1Status,
    required this.day1Label,
    required this.day2Status,
    required this.day2Label,
    required this.day3Status,
    required this.day3Label,
    required this.firstProofStatus,
    required this.firstProofLabel,
    required this.feedbackStatus,
    required this.feedbackLabel,
    required this.entryCount,
    required this.firstProofReached,
    required this.firstProofTruthAnswered,
    required this.feedbackSent,
    required this.showSendFeedbackSecondary,
  });

  final BetaTestScriptRowStatus day1Status;
  final String day1Label;
  final BetaTestScriptRowStatus day2Status;
  final String day2Label;
  final BetaTestScriptRowStatus day3Status;
  final String day3Label;
  final BetaTestScriptRowStatus firstProofStatus;
  final String firstProofLabel;
  final BetaTestScriptRowStatus feedbackStatus;
  final String feedbackLabel;
  final int entryCount;
  final bool firstProofReached;
  final bool firstProofTruthAnswered;
  final bool feedbackSent;
  final bool showSendFeedbackSecondary;
}

/// Compact beta mission card on Record ready.
class BetaTestScriptCompactCard {
  const BetaTestScriptCompactCard({
    required this.title,
    required this.body,
    required this.phase,
    required this.showSendFeedbackSecondary,
  });

  final String title;
  final String body;
  final BetaTestScriptCompactPhase phase;
  final bool showSendFeedbackSecondary;
}

/// Full 3-day tester script content.
class BetaTestScriptPlan {
  const BetaTestScriptPlan({
    required this.title,
    required this.intro,
    required this.days,
    required this.successHeading,
    required this.successQuestions,
    required this.failureHeading,
    required this.progress,
  });

  final String title;
  final String intro;
  final List<BetaTestScriptDayPlan> days;
  final String successHeading;
  final List<String> successQuestions;
  final String failureHeading;
  final BetaTestScriptProgressSummary progress;
}
