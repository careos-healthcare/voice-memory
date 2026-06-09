import '../../models/journal_entry.dart';

class MemoryResurfacingCardData {
  const MemoryResurfacingCardData({
    required this.entry,
    required this.headline,
    required this.quoteSnippet,
    required this.originalDateLabel,
    required this.beliefRelation,
  });

  final JournalEntry entry;
  final String headline;
  final String quoteSnippet;
  final String originalDateLabel;
  final String beliefRelation;
}

class MemoryResurfacingStats {
  const MemoryResurfacingStats({
    required this.resurfacedCount,
    required this.openedCount,
  });

  final int resurfacedCount;
  final int openedCount;
}
