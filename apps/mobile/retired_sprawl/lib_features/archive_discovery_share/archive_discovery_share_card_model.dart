import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_copy.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_types.dart';

/// One shareable archive moment — premium PNG + system share sheet (V2).
class ArchiveDiscoveryShareCardModel {
  const ArchiveDiscoveryShareCardModel({
    required this.id,
    required this.type,
    required this.insight,
    required this.evidenceRecordingCount,
    this.introLine = ArchiveDiscoveryShareCopy.introLine,
    this.footer = ArchiveDiscoveryShareCopy.footer,
  });

  final String id;
  final ArchiveDiscoveryShareCardType type;
  final String introLine;

  /// Main insight — plain language, no forced quote wrapping in storage.
  final String insight;
  final int evidenceRecordingCount;
  final String footer;

  String get evidenceLine =>
      ArchiveDiscoveryShareCopy.evidenceLine(evidenceRecordingCount);

  String get pngFilename => 'archiveme-discovery-$id.png';

  bool get hasEvidenceCount => evidenceRecordingCount > 0;
}