/// Visibility gates for first-week path surfaces.
abstract final class FirstWeekPathGates {
  FirstWeekPathGates._();

  static bool showOnArchiveHome({
    required int realEntryCount,
    required bool isComplete,
    required bool sampleMode,
  }) {
    if (sampleMode) return false;
    if (isComplete) return false;
    return realEntryCount <= 7;
  }

  static bool showScreenshotPreview({required bool sampleMode}) => sampleMode;
}
