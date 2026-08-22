import 'package:archiveme_mobile/features/belief_changes/belief_shift_engine.dart';
import 'package:archiveme_mobile/features/discover/chapter_engine.dart';
import 'package:archiveme_mobile/features/discover/discover_engine.dart';
import 'package:archiveme_mobile/features/discover/theme_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Ownership metrics for the archive progress identity card.
class ArchiveProgressIdentity {
  const ArchiveProgressIdentity({
    required this.recordings,
    required this.themesDiscovered,
    required this.beliefChanges,
    required this.activeLifeChapters,
    required this.archiveAgeDays,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int recordings;
  final int themesDiscovered;
  final int beliefChanges;
  final int activeLifeChapters;
  final int archiveAgeDays;
  final int currentStreak;
  final int longestStreak;
}

class ArchiveProgressIdentityBuilder {
  const ArchiveProgressIdentityBuilder();

  ArchiveProgressIdentity build(
    List<JournalEntry> entries, {
    String? currentBelief,
  }) {
    if (entries.isEmpty) {
      return const ArchiveProgressIdentity(
        recordings: 0,
        themesDiscovered: 0,
        beliefChanges: 0,
        activeLifeChapters: 0,
        archiveAgeDays: 0,
        currentStreak: 0,
        longestStreak: 0,
      );
    }

    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first.createdAt.toLocal();
    final today = DateTime.now();
    final ageDays = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(first.year, first.month, first.day)).inDays;

    final themeKeys = DiscoverLocalThemeCounts.count(entries).keys.length;
    final shifts = const BeliefShiftEngine()
        .detect(entries: entries, currentBelief: currentBelief)
        .reports
        .length;
    final chapters = const DiscoverChapterEngine().build(entries).length;

    const engine = DiscoverYourselfEngine();
    final snapshot = engine.build(entries: entries);
    final momentum = snapshot.momentum;

    return ArchiveProgressIdentity(
      recordings: entries.length,
      themesDiscovered: themeKeys,
      beliefChanges: shifts,
      activeLifeChapters: chapters,
      archiveAgeDays: ageDays.clamp(0, 99999),
      currentStreak: momentum?.currentStreak ?? 0,
      longestStreak: momentum?.longestStreak ?? 0,
    );
  }
}