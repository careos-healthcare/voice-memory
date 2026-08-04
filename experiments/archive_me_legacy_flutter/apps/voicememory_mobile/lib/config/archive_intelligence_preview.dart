import '../features/archive_evidence/archive_intelligence_tier.dart';
import 'app_feature_flags.dart';

/// QA override for archive intelligence depth.
///
/// `--dart-define=ARCHIVE_INTELLIGENCE_PREVIEW=free`
/// `--dart-define=ARCHIVE_INTELLIGENCE_PREVIEW=pro`
abstract class ArchiveIntelligencePreview {
  ArchiveIntelligencePreview._();

  static const String _raw = AppFeatureFlags.archiveIntelligencePreview;

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
