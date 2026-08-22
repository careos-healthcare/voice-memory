import 'package:archiveme_mobile/features/discover/discover_models.dart';
import 'package:archiveme_mobile/features/life_chapters/life_chapter_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Life chapter summaries for Discover Yourself.
class DiscoverChapterEngine {
  const DiscoverChapterEngine();

  List<DiscoverChapterSummary> build(List<JournalEntry> entries) {
    final result = const LifeChapterEngine().build(entries: entries);
    if (!result.hasChapters) return const [];

    return result.chapters
        .map(
          (c) => DiscoverChapterSummary(
            id: c.id,
            title: c.title,
            startDate: c.startDate,
            endDate: c.endDate,
            summary: c.themeSummary,
            entryCount: c.evidenceIds.length,
            entryIds: c.evidenceIds,
          ),
        )
        .toList();
  }
}