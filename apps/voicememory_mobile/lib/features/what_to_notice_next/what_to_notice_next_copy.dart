import 'what_to_notice_next_model.dart';

/// Observation guidance copy — notice first, record only if something stands out.
abstract final class WhatToNoticeNextCopy {
  WhatToNoticeNextCopy._();

  static const title = 'What to notice next';

  static const body =
      'You do not need to force an entry. Just notice if one of these shows up.';

  static const closingLine = 'If nothing stands out, skip today.';

  static String promptTextFor(WhatToNoticeNextPromptType type) =>
      switch (type) {
        WhatToNoticeNextPromptType.doesThisComeBack => 'Does this come back?',
        WhatToNoticeNextPromptType.doesItFeelLighter =>
          'Does it feel lighter?',
        WhatToNoticeNextPromptType.didAnythingHelp => 'Did anything help?',
        WhatToNoticeNextPromptType.didYouAvoidItAgain =>
          'Did you avoid it again?',
        WhatToNoticeNextPromptType.didItFeelHeavier =>
          'Did it feel heavier than expected?',
        WhatToNoticeNextPromptType.didSomethingChange =>
          'Did something change since last time?',
        WhatToNoticeNextPromptType.whatStoodOut => 'What stood out today?',
        WhatToNoticeNextPromptType.whatFeltHeavier =>
          'What felt heavier than it should?',
        WhatToNoticeNextPromptType.whatHelped => 'What helped a little?',
        WhatToNoticeNextPromptType.whatNotToForget =>
          'What do you not want to forget?',
      };

  static const noticePromptTypes = [
    WhatToNoticeNextPromptType.doesThisComeBack,
    WhatToNoticeNextPromptType.doesItFeelLighter,
    WhatToNoticeNextPromptType.didAnythingHelp,
    WhatToNoticeNextPromptType.didYouAvoidItAgain,
    WhatToNoticeNextPromptType.didItFeelHeavier,
    WhatToNoticeNextPromptType.didSomethingChange,
  ];

  static const fallbackPromptTypes = [
    WhatToNoticeNextPromptType.whatStoodOut,
    WhatToNoticeNextPromptType.whatFeltHeavier,
    WhatToNoticeNextPromptType.whatHelped,
    WhatToNoticeNextPromptType.whatNotToForget,
  ];

  static List<String> allVisibleStrings() => [
        title,
        body,
        closingLine,
        for (final type in WhatToNoticeNextPromptType.values)
          promptTextFor(type),
      ];
}
