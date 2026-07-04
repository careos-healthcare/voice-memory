import 'what_changed_v2_model.dart';

/// User-facing copy for What Changed v2 — user-reported evidence only.
abstract final class WhatChangedV2Copy {
  WhatChangedV2Copy._();

  static const question = 'What changed this time?';

  static const savedStronger =
      'Saved. ArchiveMe will watch whether this is getting louder.';
  static const savedSofter =
      'Saved. ArchiveMe will watch whether this is softening.';
  static const savedSame =
      'Saved. ArchiveMe will keep comparing this pattern.';
  static const savedDifferent =
      'Saved. ArchiveMe will watch what changed in your response.';
  static const savedSomethingHelped =
      'Saved. ArchiveMe will watch whether that helps again.';

  static String savedMessage(WhatChangedV2Option option) => switch (option) {
        WhatChangedV2Option.stronger => savedStronger,
        WhatChangedV2Option.softer => savedSofter,
        WhatChangedV2Option.same => savedSame,
        WhatChangedV2Option.differentResponse => savedDifferent,
        WhatChangedV2Option.somethingHelped => savedSomethingHelped,
      };

  static String weeklyReviewLine(WhatChangedV2Option option) =>
      switch (option) {
        WhatChangedV2Option.stronger =>
          'You marked that the repeat felt stronger this time.',
        WhatChangedV2Option.softer =>
          'You marked that the repeat felt softer this time.',
        WhatChangedV2Option.same =>
          'You marked that the repeat felt the same this time.',
        WhatChangedV2Option.differentResponse =>
          'You marked that you responded differently this time.',
        WhatChangedV2Option.somethingHelped =>
          'You marked that something helped this time.',
      };
}
