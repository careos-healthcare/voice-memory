import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart' show BetaSurfacesFeatureFlags;
import 'package:archiveme_mobile/core/config/image_evidence_feature_flags.dart' show ImageEvidenceFeatureFlags;
import 'package:archiveme_mobile/core/config/theory_tracking_feature_flags.dart' show TheoryTrackingFeatureFlags;
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart' show CaregiverFeatureFlags;

/// Guards internal insight-science scoring from consumer UI surfaces.
///
/// Beta insight surfaces (Lenses, Ask Archive, Coach, Image Evidence, Live
/// Conversation) additionally require [BetaSurfacesFeatureFlags.enableBetaSurfaces]
/// and must pass `npm run validate:insight-quality-gate` before shipping.
///
/// **Selective reactivation (not one block):**
/// - [TheoryTrackingFeatureFlags] — `/theories` and breakthrough tracking
/// - [ImageEvidenceFeatureFlags] via beta surfaces — real UI in
///   `image_evidence_attachment_panel.dart`, not flag-only
///
/// **Deferred internal scoring (stay off):**
/// - `insight-ingredient-optimizer`, `a-tier-prioritization`
///
/// **Separate persona gates (not beta surfaces):**
/// - [CaregiverFeatureFlags] — monitoring mode + server consent; see
///   `docs/CAREGIVER_MONITORING.md`
abstract final class InsightScienceDeferredGuard {
  InsightScienceDeferredGuard._();

  static const deferredInternalScoringModules = [
    'insight-ingredient-optimizer',
    'a-tier-prioritization',
  ];

  /// Product UI must not expose ingredient tiers or A-tier prioritization badges.
  static bool get exposeInternalScoringInUi => false;
}