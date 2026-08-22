/// Visibility gates for archive clarity surfaces.
abstract final class ArchiveClarityGates {
  ArchiveClarityGates._();

  static bool showOnArchiveHome({required bool sampleMode}) => !sampleMode;
}