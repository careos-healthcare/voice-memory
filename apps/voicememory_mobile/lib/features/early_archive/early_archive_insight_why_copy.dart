/// Calm, grounded copy for expandable early insight explanations.
abstract final class EarlyArchiveInsightWhyCopy {
  EarlyArchiveInsightWhyCopy._();

  static const linkLabel = 'Why ArchiveMe thinks this';

  static String seenAcrossEntries(int count) =>
      'Seen across $count ${count == 1 ? 'entry' : 'entries'}.';

  static String similarWordingAround(Iterable<String> topics) {
    final labels = topics.toList();
    if (labels.isEmpty) {
      return 'Similar wording appeared across recent entries.';
    }
    return 'Similar wording appeared around ${labels.join(' / ')}.';
  }

  static const latestLessUrgent = 'The latest entry sounded less urgent.';

  static const helpfulActionOnce = 'A helpful action was captured once.';

  static const triggerInLaterEntry =
      'Trigger wording appeared in a later entry.';
}
