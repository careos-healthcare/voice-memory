import 'save_a_repeat_habit_copy.dart';

/// Save-a-repeat habit — simple trigger without daily pressure or gamification.
abstract final class SaveARepeatHabit {
  SaveARepeatHabit._();

  static SaveARepeatHabitResult resolve(SaveARepeatHabitInput input) {
    if (!input.userUnderstandsRepeatTrigger) {
      return _result(SaveARepeatHabitDecision.clarifyRepeatTrigger);
    }
    if (!input.userUnderstandsOneSentenceEnough) {
      return _result(SaveARepeatHabitDecision.clarifyOneSentenceEnough);
    }
    if (input.userFeelsDailyPressure) {
      return _result(SaveARepeatHabitDecision.clarifyNoDailyPressure);
    }
    if (input.userFeelsDashboardMaintenance) {
      return _result(SaveARepeatHabitDecision.clarifyNoDashboardMaintenance);
    }
    if (!input.userUnderstandsArchiveComparesLater) {
      return _result(SaveARepeatHabitDecision.clarifyArchiveComparesLater);
    }
    if (input.userStillUsesChatGptByHabit) {
      return _result(SaveARepeatHabitDecision.clarifyChatGptHabitDifference);
    }
    if (input.userStillUsesNotesByHabit) {
      return _result(SaveARepeatHabitDecision.clarifyNotesHabitDifference);
    }
    if (_comprehensionPasses(input) && !_paymentPasses(input)) {
      return _result(SaveARepeatHabitDecision.pricingValidation);
    }
    if (_comprehensionPasses(input) && _paymentPasses(input)) {
      return _result(SaveARepeatHabitDecision.releaseCandidate);
    }
    return _result(SaveARepeatHabitDecision.clarifyRepeatTrigger);
  }

  static SaveARepeatHabitReport report(SaveARepeatHabitResult result) =>
      SaveARepeatHabitReport(
        headline: SaveARepeatHabitCopy.headline,
        body: SaveARepeatHabitCopy.body,
        triggerLine: SaveARepeatHabitCopy.triggerLine,
        oneSentenceLine: SaveARepeatHabitCopy.oneSentenceLine,
        notDailyLine: SaveARepeatHabitCopy.notDailyLine,
        whyItMattersLine: SaveARepeatHabitCopy.whyItMattersLine,
        chatDifferenceLine: SaveARepeatHabitCopy.chatDifferenceLine,
        notesDifferenceLine: SaveARepeatHabitCopy.notesDifferenceLine,
        proLine: SaveARepeatHabitCopy.proLine,
        guardrail: SaveARepeatHabitCopy.guardrail,
        result: result,
      );

  static bool _comprehensionPasses(SaveARepeatHabitInput input) =>
      input.userUnderstandsRepeatTrigger &&
      input.userUnderstandsOneSentenceEnough &&
      !input.userFeelsDailyPressure &&
      !input.userFeelsDashboardMaintenance &&
      input.userUnderstandsArchiveComparesLater &&
      !input.userStillUsesChatGptByHabit &&
      !input.userStillUsesNotesByHabit;

  static bool _paymentPasses(SaveARepeatHabitInput input) =>
      input.wouldPayYes || input.wouldPayMaybe;

  static SaveARepeatHabitResult _result(SaveARepeatHabitDecision decision) =>
      SaveARepeatHabitResult(
        decision: decision,
        message: _messageFor(decision),
      );

  static String _messageFor(SaveARepeatHabitDecision decision) =>
      switch (decision) {
        SaveARepeatHabitDecision.clarifyRepeatTrigger =>
          SaveARepeatHabitCopy.triggerLine,
        SaveARepeatHabitDecision.clarifyOneSentenceEnough =>
          SaveARepeatHabitCopy.oneSentenceLine,
        SaveARepeatHabitDecision.clarifyNoDailyPressure =>
          SaveARepeatHabitCopy.notDailyLine,
        SaveARepeatHabitDecision.clarifyNoDashboardMaintenance =>
          SaveARepeatHabitCopy.notDailyLine,
        SaveARepeatHabitDecision.clarifyArchiveComparesLater =>
          SaveARepeatHabitCopy.whyItMattersLine,
        SaveARepeatHabitDecision.clarifyChatGptHabitDifference =>
          SaveARepeatHabitCopy.chatDifferenceLine,
        SaveARepeatHabitDecision.clarifyNotesHabitDifference =>
          SaveARepeatHabitCopy.notesDifferenceLine,
        SaveARepeatHabitDecision.pricingValidation =>
          SaveARepeatHabitCopy.proLine,
        SaveARepeatHabitDecision.releaseCandidate =>
          SaveARepeatHabitCopy.headline,
      };
}

enum SaveARepeatHabitDecision {
  clarifyRepeatTrigger,
  clarifyOneSentenceEnough,
  clarifyNoDailyPressure,
  clarifyArchiveComparesLater,
  clarifyChatGptHabitDifference,
  clarifyNotesHabitDifference,
  clarifyNoDashboardMaintenance,
  pricingValidation,
  releaseCandidate,
}

class SaveARepeatHabitInput {
  const SaveARepeatHabitInput({
    required this.userUnderstandsSaveRepeat,
    required this.userStillUsesChatGptByHabit,
    required this.userStillUsesNotesByHabit,
    required this.userFeelsDailyPressure,
    required this.userFeelsDashboardMaintenance,
    required this.userUnderstandsOneSentenceEnough,
    required this.userUnderstandsArchiveComparesLater,
    required this.userUnderstandsRepeatTrigger,
    required this.wouldPayYes,
    required this.wouldPayMaybe,
  });

  final bool userUnderstandsSaveRepeat;
  final bool userStillUsesChatGptByHabit;
  final bool userStillUsesNotesByHabit;
  final bool userFeelsDailyPressure;
  final bool userFeelsDashboardMaintenance;
  final bool userUnderstandsOneSentenceEnough;
  final bool userUnderstandsArchiveComparesLater;
  final bool userUnderstandsRepeatTrigger;
  final bool wouldPayYes;
  final bool wouldPayMaybe;
}

class SaveARepeatHabitResult {
  const SaveARepeatHabitResult({
    required this.decision,
    required this.message,
  });

  final SaveARepeatHabitDecision decision;
  final String message;
}

class SaveARepeatHabitReport {
  const SaveARepeatHabitReport({
    required this.headline,
    required this.body,
    required this.triggerLine,
    required this.oneSentenceLine,
    required this.notDailyLine,
    required this.whyItMattersLine,
    required this.chatDifferenceLine,
    required this.notesDifferenceLine,
    required this.proLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String triggerLine;
  final String oneSentenceLine;
  final String notDailyLine;
  final String whyItMattersLine;
  final String chatDifferenceLine;
  final String notesDifferenceLine;
  final String proLine;
  final String guardrail;
  final SaveARepeatHabitResult result;
}
