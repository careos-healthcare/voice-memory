import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';

/// V1 retention rebalance — quarantines Tier 3a mechanics from consumer surfaces.
///
/// Under [V1FeatureFlags.enableV1Only], clinical biomarkers stay in the
/// clinical sandbox, streak counts are de-emphasized, and curiosity/pressure
/// triggers require anchored archive evidence rather than generic timing.
abstract final class V1RetentionPolicy {
  V1RetentionPolicy._();

  static bool get enableV1Only => V1FeatureFlags.enableV1Only;

  /// Clinical trajectory / biomarker signals must not drive consumer hooks.
  static bool get quarantineClinicalConsumerSignals => enableV1Only;

  /// Hide prominent streak-count motivational UI (tracking continues locally).
  static bool get hideProminentStreakUi => enableV1Only;

  /// Capacity-loop and pressure return cards on Record post-save.
  static bool get showCapacityReturnTriggers => !enableV1Only;

  /// Post-save curiosity hook cards on Record.
  static bool get showCuriosityPostSaveHooks => !enableV1Only;

  /// Advanced retention post-save block (streak card, commitment cards).
  static bool get showAdvancedRetentionPostSave => !enableV1Only;

  /// Curiosity / pressure hooks require a concrete journal entry anchor.
  static bool get requireEvidenceAnchoredHooks => enableV1Only;
}