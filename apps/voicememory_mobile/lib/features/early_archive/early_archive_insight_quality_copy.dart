/// Safe fallback copy when early insight evidence is too thin to summarize.
abstract final class EarlyArchiveInsightQualityCopy {
  EarlyArchiveInsightQualityCopy._();

  static const repeatFallback =
      'ArchiveMe has seen this come back across 3 moments.';

  static const twoEntryRepeatFallback = 'ArchiveMe noticed this came up again.';

  static const timelineRepeatFallback = 'Seen across 3 moments.';

  static const triggerFallback = 'You recorded what happened right before it.';

  static const softeningFallback = 'One later entry sounded less urgent.';

  static const helpfulActionFallback =
      'You mentioned something that may have helped.';

  static const timelineSubtitleFallback =
      'ArchiveMe is tracking what repeats, what starts it, and what may help '
      'it soften.';

  static const changeNoticeBodyFallback =
      'The same loop came back, but your archive noticed it may have been softer.';

  static const triggerPayoffBodyFallback =
      'You mentioned what happened right before it. That gives ArchiveMe '
      'stronger evidence for what starts this loop.';

  static const helpfulActionPayoffBodyFallback =
      'You mentioned something that may have softened the loop. Your archive is watching whether it shows up again.';
}
