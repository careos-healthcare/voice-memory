import 'package:archiveme_mobile/features/archive_evidence/archive_intelligence_tier.dart';

/// QA override for archive intelligence depth.
///
/// `--dart-define=ARCHIVE_INTELLIGENCE_PREVIEW=free`
/// `--dart-define=ARCHIVE_INTELLIGENCE_PREVIEW=pro`
abstract class ArchiveIntelligencePreview {
  ArchiveIntelligencePreview._();

  static const String _raw = String.fromEnvironment(
    'ARCHIVE_INTELLIGENCE_PREVIEW',
  );

  static ArchiveIntelligenceTier? get forcedTier {
    switch (_raw.trim().toLowerCase()) {
      case 'free':
        return ArchiveIntelligenceTier.freeMedium;
      case 'pro':
        return ArchiveIntelligenceTier.proMax;
      default:
        return null;
    }
  }
}