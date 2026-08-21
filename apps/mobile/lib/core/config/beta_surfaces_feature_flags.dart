import 'package:archiveme_mobile/core/config/image_evidence_feature_flags.dart';
import 'package:archiveme_mobile/core/config/live_conversation_feature_flags.dart';
import 'package:archiveme_mobile/core/config/professional_coach_feature_flags.dart';
import 'package:meta/meta.dart';

/// Master compile-time gate for insight-quality-bar beta surfaces (PRD Goal #4).
///
/// Default off — production builds must not expose Lenses, Ask Archive, Coach
/// tier, Image Evidence, or Live Conversation until this flag and the
/// insight-quality CI gate (`validate:insight-quality-gate`) pass review.
///
/// Enable locally: `--dart-define=VOICE_MEMORY_ENABLE_BETA_SURFACES=true`
abstract final class BetaSurfacesFeatureFlags {
  BetaSurfacesFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICE_MEMORY_ENABLE_BETA_SURFACES',
  );

  @visibleForTesting
  static bool? debugOverride;

  static bool get enableBetaSurfaces => debugOverride ?? _compileTimeDefault;

  /// Thematic life-stage lenses (`activeLens`) and onboarding selector.
  static bool get thematicLenses => enableBetaSurfaces;

  /// Ask My Archive — entry bar on ArchiveBeliefScreen + `/ask-archive` route.
  static bool get askArchive => enableBetaSurfaces;

  /// Professional / coach tier routing and account surfaces.
  static bool get professionalCoach =>
      enableBetaSurfaces &&
      ProfessionalCoachFeatureFlags.enableProfessionalCoach;

  /// Gemini live conversation mode on Record.
  static bool get liveConversation =>
      enableBetaSurfaces && LiveConversationFeatureFlags.enabled;

  /// Camera / gallery image evidence attachments.
  static bool get imageEvidence =>
      enableBetaSurfaces && ImageEvidenceFeatureFlags.enableImageEvidence;
}