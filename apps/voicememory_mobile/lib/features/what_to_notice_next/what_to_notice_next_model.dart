/// Lightweight observation prompts — no classification, no categories.
enum WhatToNoticeNextPromptType {
  doesThisComeBack,
  doesItFeelLighter,
  didAnythingHelp,
  didYouAvoidItAgain,
  didItFeelHeavier,
  didSomethingChange,
  whatStoodOut,
  whatFeltHeavier,
  whatHelped,
  whatNotToForget,
}

extension WhatToNoticeNextPromptTypeStorage on WhatToNoticeNextPromptType {
  String get analyticsValue => switch (this) {
        WhatToNoticeNextPromptType.doesThisComeBack => 'does_this_come_back',
        WhatToNoticeNextPromptType.doesItFeelLighter => 'does_it_feel_lighter',
        WhatToNoticeNextPromptType.didAnythingHelp => 'did_anything_help',
        WhatToNoticeNextPromptType.didYouAvoidItAgain => 'did_you_avoid_it_again',
        WhatToNoticeNextPromptType.didItFeelHeavier => 'did_it_feel_heavier',
        WhatToNoticeNextPromptType.didSomethingChange => 'did_something_change',
        WhatToNoticeNextPromptType.whatStoodOut => 'what_stood_out',
        WhatToNoticeNextPromptType.whatFeltHeavier => 'what_felt_heavier',
        WhatToNoticeNextPromptType.whatHelped => 'what_helped',
        WhatToNoticeNextPromptType.whatNotToForget => 'what_not_to_forget',
      };
}

class WhatToNoticeNextPrompt {
  const WhatToNoticeNextPrompt({
    required this.type,
    required this.text,
  });

  final WhatToNoticeNextPromptType type;
  final String text;
}

class WhatToNoticeNextResult {
  const WhatToNoticeNextResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.prompts,
    required this.closingLine,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasTimeline,
    required this.usesFallbackPrompts,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final List<WhatToNoticeNextPrompt> prompts;
  final String closingLine;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasTimeline;
  final bool usesFallbackPrompts;
}
