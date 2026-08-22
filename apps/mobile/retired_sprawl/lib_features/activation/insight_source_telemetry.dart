import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart' show ActivationTracker;
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show ActivationTracker;

/// Required metadata keys for insight-quality metric isolation (PRD Goal #4).
///
/// Attach via [ActivationTracker.trackEvent] payloads so time-to-first-accurate
/// insight and specificity rate can be segmented by surface vs v1 baseline.
abstract final class InsightSourceTelemetry {
  InsightSourceTelemetry._();

  static const sourceLens = 'source_lens';
  static const sourceMode = 'source_mode';
  static const sourceSurface = 'source_surface';

  static const surfaceV1Baseline = 'v1_baseline';
  static const surfaceAskArchive = 'ask_archive';
  static const surfaceLiveConversation = 'live_conversation';
  static const surfaceImageEvidence = 'image_evidence';
  static const surfaceCoachTier = 'coach_tier';
  static const surfaceLifeStageOnboarding = 'life_stage_onboarding';

  static const modePassiveCapture = 'passive_capture';
  static const modeLiveConversation = 'live_conversation';

  static Map<String, String> forSurface(String surface) => {
        sourceSurface: surface,
      };

  static Map<String, String> forLens(LifeStageLens? lens) => {
        if (lens != null && lens != LifeStageLens.defaultLens)
          sourceLens: lens.wireValue,
      };

  static Map<String, String> forLiveConversation() => {
        sourceMode: modeLiveConversation,
        sourceSurface: surfaceLiveConversation,
      };

  static Map<String, String> merge(
    Map<String, String> base,
    Map<String, String> extra,
  ) =>
      {...base, ...extra};
}