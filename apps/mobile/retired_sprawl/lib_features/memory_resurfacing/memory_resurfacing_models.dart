import 'package:archiveme_mobile/models/journal_entry.dart';

/// A place stored with a memory. The feed draws a static snippet from it.
class MemoryPlace {
  const MemoryPlace({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

class MemoryResurfacingCardData {
  const MemoryResurfacingCardData({
    required this.entry,
    required this.headline,
    required this.quoteSnippet,
    required this.originalDateLabel,
    required this.beliefRelation,
    this.imageUrls = const [],
    this.place,
  });

  final JournalEntry entry;
  final String headline;
  final String quoteSnippet;
  final String originalDateLabel;
  final String beliefRelation;

  /// Remote stills attached to this memory. Empty hides the photo grid.
  final List<String> imageUrls;

  /// Present when the entry has location metadata.
  final MemoryPlace? place;

  /// Local or remote voice note. Empty hides the wavebar.
  String? get audioPath {
    final path = entry.localAudioPath?.trim();
    if (path == null || path.isEmpty) return null;
    return path;
  }
}

class MemoryResurfacingStats {
  const MemoryResurfacingStats({
    required this.resurfacedCount,
    required this.openedCount,
  });

  final int resurfacedCount;
  final int openedCount;
}
