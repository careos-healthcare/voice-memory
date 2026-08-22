import 'package:archiveme_mobile/features/archive_watchlist/archive_watchlist_copy.dart';

/// Visibility gates for archive watchlist surfaces.
abstract final class ArchiveWatchlistGates {
  ArchiveWatchlistGates._();

  static bool showTeaser({required int entryCount, required bool sampleMode}) =>
      !sampleMode && entryCount == 0;

  static bool showCard({required int entryCount, required bool sampleMode}) =>
      !sampleMode && entryCount >= 1;

  static bool showProLine({
    required int watchThemeCount,
    required int entryCount,
  }) => watchThemeCount >= ArchiveWatchlistCopy.maxThemes || entryCount >= 10;

  static bool canAddTheme(int currentCount) =>
      currentCount < ArchiveWatchlistCopy.maxThemes;
}