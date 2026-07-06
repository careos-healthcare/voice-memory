import 'what_changed_v2_model.dart';

/// User-facing copy for What Changed v3 — last time vs this time.
abstract final class WhatChangedV2Copy {
  WhatChangedV2Copy._();

  static const question = 'What changed since last time?';

  static const body =
      'ArchiveMe has seen this thread before. Mark what felt different this time.';

  static const thenLabel = 'Then';

  static const nowLabel = 'Now';

  static const payoffSofter =
      'Last time it looked stronger. This time it may have softened.';

  static const payoffStronger =
      'This may be getting louder. ArchiveMe will keep watching.';

  static const payoffSame = 'This looks similar to last time.';

  static const payoffDifferent = 'This time, your response changed.';

  static const payoffHelped =
      'Something helped this time. ArchiveMe will remember that.';

  static String payoffMessage(WhatChangedV2Option option) => switch (option) {
        WhatChangedV2Option.softer => payoffSofter,
        WhatChangedV2Option.stronger => payoffStronger,
        WhatChangedV2Option.same => payoffSame,
        WhatChangedV2Option.differentResponse => payoffDifferent,
        WhatChangedV2Option.somethingHelped => payoffHelped,
      };

  /// Legacy alias kept for weekly review and external references.
  static String savedMessage(WhatChangedV2Option option) =>
      payoffMessage(option);

  static String weeklyReviewLine(WhatChangedV2Option option) =>
      payoffMessage(option);

  static String formatSnippet(String quote) => '"$quote"';

  static List<String> allVisibleStrings() => [
        question,
        body,
        thenLabel,
        nowLabel,
        payoffSofter,
        payoffStronger,
        payoffSame,
        payoffDifferent,
        payoffHelped,
      ];
}
