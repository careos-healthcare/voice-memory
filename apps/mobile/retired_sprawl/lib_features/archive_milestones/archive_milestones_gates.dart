/// Visibility gates for archive milestones surfaces.
abstract final class ArchiveMilestonesGates {
  ArchiveMilestonesGates._();

  static bool showOnArchive({required bool sampleMode}) => !sampleMode;

  static bool showProLine({required int savedCount}) => savedCount >= 10;
}