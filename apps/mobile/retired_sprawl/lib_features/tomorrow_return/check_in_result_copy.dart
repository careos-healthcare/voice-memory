/// Plain-language result copy for completed tomorrow check-ins.
abstract class CheckInResultCopy {
  CheckInResultCopy._();

  static String resultHeadline(String? selectedOptionId) {
    switch (selectedOptionId) {
      case 'showed_up_again':
        return 'It showed up again.';
      case 'lighter':
        return 'It felt lighter today.';
      case 'heavier':
        return 'It felt heavier today.';
      case 'not_today':
        return 'Something changed today.';
      case 'none_fit':
        return 'None of those fit today.';
      default:
        return 'You closed the loop.';
    }
  }

  static String whatThisMeans(String? selectedOptionId) {
    switch (selectedOptionId) {
      case 'showed_up_again':
        return 'This pattern may still be active. The useful part is that you caught the moment.';
      case 'lighter':
        return 'This may be getting easier to notice or interrupt.';
      case 'heavier':
        return 'This pattern may need more attention tomorrow.';
      case 'not_today':
        return 'Something was different today. That can be just as useful as a repeat.';
      case 'none_fit':
        return 'Today did not match the usual answers. Naming it in your own words is still useful.';
      default:
        return 'You answered what happened today.';
    }
  }

  static String tomorrowsBetterQuestion(String? selectedOptionId) {
    switch (selectedOptionId) {
      case 'showed_up_again':
        return 'What happens right before it shows up?';
      case 'lighter':
        return 'What helped make it lighter?';
      case 'heavier':
        return 'What made it heavier?';
      case 'not_today':
        return 'What was different today?';
      case 'none_fit':
        return 'What actually happened today?';
      default:
        return 'What do you want to check tomorrow?';
    }
  }

  /// Section title for the gated "better result" interpretation.
  static const String whyThisIsUsefulTitle = 'Why this is useful';

  /// Plain explanation of why the result matters, gated by diagnosis.
  ///
  /// When the user previously said the result was not useful, [notUsefulReason]
  /// tailors the wording to that complaint.
  static String whyThisIsUseful(
    String? selectedOptionId, {
    String? notUsefulReason,
  }) {
    switch (notUsefulReason) {
      case 'too_vague':
        return _concreteWhyUseful(selectedOptionId);
      case 'not_accurate':
        return 'This may not be exact yet. Your next answer helps correct it.';
      case 'already_knew_this':
        return 'The value is tracking whether it changes, not just naming it.';
      case 'confusing':
        return _shortWhyUseful(selectedOptionId);
    }
    return _baseWhyUseful(selectedOptionId);
  }

  static String _baseWhyUseful(String? selectedOptionId) {
    switch (selectedOptionId) {
      case 'showed_up_again':
        return 'You now know the pattern is still active. Tomorrow, watch what happens right before it starts.';
      case 'lighter':
        return 'You now know something helped. Tomorrow, watch what made it easier.';
      case 'heavier':
        return 'You now know this needs attention. Tomorrow, watch what made it heavier.';
      case 'not_today':
        return 'You now know the day was different. Tomorrow, watch what changed.';
      default:
        return 'You now know what happened today. Tomorrow, watch what changes.';
    }
  }

  static String _concreteWhyUseful(String? selectedOptionId) {
    switch (selectedOptionId) {
      case 'showed_up_again':
        return 'You now know it happened again. Tomorrow, watch the exact moment it starts.';
      case 'lighter':
        return 'You now know one thing helped. Tomorrow, name what made it easier.';
      case 'heavier':
        return 'You now know it weighed on you. Tomorrow, name what made it heavier.';
      case 'not_today':
        return 'You now know today was different. Tomorrow, name the one thing that changed.';
      default:
        return 'You now know what happened today. Tomorrow, name the one thing that changed.';
    }
  }

  static String _shortWhyUseful(String? selectedOptionId) {
    switch (selectedOptionId) {
      case 'showed_up_again':
        return 'It showed up again, so the pattern is still active.';
      case 'lighter':
        return 'Something made today lighter.';
      case 'heavier':
        return 'Today was heavier, so this needs attention.';
      case 'not_today':
        return 'Today was different.';
      default:
        return 'You answered what happened today.';
    }
  }

  /// Section title for the aggressive "Try this next" guidance.
  static const String tryThisNextTitle = 'Try this next';

  /// Result-based next step shown in aggressive better-result mode.
  static String tryThisNext(String? selectedOptionId) {
    switch (selectedOptionId) {
      case 'showed_up_again':
        return 'Next time, notice the moment right before it starts.';
      case 'lighter':
        return 'Next time, notice what helped make it easier.';
      case 'heavier':
        return 'Next time, notice what made it harder.';
      case 'not_today':
        return 'Next time, notice what was different.';
      default:
        return 'Next time, notice one moment that stayed with you.';
    }
  }

  /// Targeted guidance for the top "not useful" complaint, or null.
  static String? tryThisNextReason(String? notUsefulReason) {
    switch (notUsefulReason) {
      case 'too_vague':
        return 'Make it concrete: name the moment, not the whole day.';
      case 'not_accurate':
        return 'Correct it next time: choose the closest answer, then record one moment.';
      case 'already_knew_this':
        return 'The value is whether it changes tomorrow.';
      case 'confusing':
        return 'Use one sentence: what happened, and how it felt.';
    }
    return null;
  }

  static const Map<String, String> optionExamples = {
    'showed_up_again':
        "It showed up again: 'I said yes before asking for help.'",
    'lighter': "It felt lighter: 'I noticed it, but paused before answering.'",
    'heavier': "It felt heavier: 'I carried it all day and felt drained.'",
    'not_today': "Not today: 'The situation did not come up.'",
  };
}