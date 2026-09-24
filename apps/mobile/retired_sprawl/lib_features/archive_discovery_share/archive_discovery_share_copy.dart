/// Archive Discovery Share Cards — screenshot-safe layout copy.
abstract class ArchiveDiscoveryShareCopy {
  ArchiveDiscoveryShareCopy._();

  static const String introLine = 'My archive noticed:';
  static const String footer = 'ArchiveMe';
  static const String shareDiscoveryLabel = 'Share Discovery';
  static const String shareSheetText = 'From my ArchiveMe archive';
  static const String sheetTitle = 'Share this discovery';

  static String evidenceLine(int recordingCount) {
    final n = recordingCount.clamp(0, 100000);
    if (n <= 0) return 'Based on your recordings';
    return 'Based on $n ${n == 1 ? 'recording' : 'recordings'}';
  }

  /// Fixed logical size for crisp PNG export (3× pixel ratio).
  static const double exportWidth = 360;
  static const double exportMinHeight = 420;
}
