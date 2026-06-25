import '../../product/archive_positioning_copy.dart';

/// Fixed timing ids for yes-moment capture — no free text.
abstract final class YesCaptureTimingIds {
  YesCaptureTimingIds._();

  static const beforeYes = 'before_yes';
  static const afterYes = 'after_yes';
  static const laterCost = 'later_cost';

  static const all = [beforeYes, afterYes, laterCost];

  static String labelFor(String id) => switch (id) {
        beforeYes => ArchivePositioningCopy.beforeLabel,
        afterYes => ArchivePositioningCopy.afterLabel,
        laterCost => ArchivePositioningCopy.laterLabel,
        _ => id,
      };
}
