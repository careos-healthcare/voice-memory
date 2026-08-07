/// Visibility gates for archive depth surfaces.
abstract final class ArchiveDepthGates {
  ArchiveDepthGates._();

  static bool showOnArchive({required bool sampleMode}) => !sampleMode;

  static bool showCompactOnRecord({
    required bool loaded,
    required int entryCount,
    required bool isPostSave,
  }) => loaded && entryCount >= 2 && !isPostSave;
}
