import '../../billing/archive_entitlement_reader.dart';
import '../../config/archive_intelligence_preview.dart';
import 'archive_intelligence_tier.dart';

/// Resolves archive intelligence tier from Pro status and QA overrides.
class ArchiveIntelligenceTierResolver {
  const ArchiveIntelligenceTierResolver({ArchiveEntitlementReader? reader})
    : _reader = reader;

  final ArchiveEntitlementReader? _reader;

  ArchiveIntelligenceTier resolveSync({required bool isPro}) {
    final forced = ArchiveIntelligencePreview.forcedTier;
    if (forced != null) return forced;
    return isPro
        ? ArchiveIntelligenceTier.proMax
        : ArchiveIntelligenceTier.freeMedium;
  }

  Future<ArchiveIntelligenceTier> resolve() async {
    final forced = ArchiveIntelligencePreview.forcedTier;
    if (forced != null) return forced;
    final reader = _reader ?? ArchiveEntitlementReader.forAccessCheck();
    final isPro = await reader.isPro;
    return isPro
        ? ArchiveIntelligenceTier.proMax
        : ArchiveIntelligenceTier.freeMedium;
  }
}
