import '../archive_watchlist/archive_watchlist_copy.dart';

/// Visibility gates for next evidence plan surfaces.
abstract final class NextEvidencePlanGates {
  NextEvidencePlanGates._();

  static bool showTeaser({required int entryCount, required bool sampleMode}) =>
      !sampleMode && entryCount == 0;

  static bool showCard({required int entryCount, required bool sampleMode}) =>
      !sampleMode && entryCount >= 1;

  static bool showProLine({
    required int entryCount,
    required int watchThemeCount,
  }) => entryCount >= 10 || watchThemeCount >= ArchiveWatchlistCopy.maxThemes;
}
