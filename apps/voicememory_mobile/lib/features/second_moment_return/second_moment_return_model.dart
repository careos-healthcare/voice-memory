enum SecondMomentReturnActionType {
  noticedSomething,
  showWhatToNotice,
  notToday,
}

enum SecondMomentReturnPromptType {
  didThisComeBack,
  didItFeelDifferent,
  didAnythingHelp,
  didYouAvoidItAgain,
  didSomethingFeelHeavier,
}

class SecondMomentReturnResult {
  const SecondMomentReturnResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.noticeLine,
    required this.noPressureLine,
    required this.noticedSomethingAction,
    required this.showWhatToNoticeAction,
    required this.notTodayAction,
    required this.afterNoticedSomething,
    required this.afterNotToday,
    required this.returnReasonLine,
    required this.prompts,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final String noticeLine;
  final String noPressureLine;
  final String noticedSomethingAction;
  final String showWhatToNoticeAction;
  final String notTodayAction;
  final String afterNoticedSomething;
  final String afterNotToday;
  final String returnReasonLine;
  final List<SecondMomentReturnPrompt> prompts;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
}

class SecondMomentReturnPrompt {
  const SecondMomentReturnPrompt({
    required this.type,
    required this.text,
  });

  final SecondMomentReturnPromptType type;
  final String text;
}
