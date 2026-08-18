import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_milestone_store.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_retention_deriver.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_tracker.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy_config.dart';

/// Post-durable-save milestone coordinator.
///
/// Must only be called after [JournalStore._writeAll] succeeds.
abstract final class BetaAnalyticsMilestoneCoordinator {
  BetaAnalyticsMilestoneCoordinator._();

  static const Duration secondSaveWindow = Duration(hours: 72);
  static const Duration thirdSaveWindow = Duration(days: 7);

  /// [activeCountAfter] is the count of non-tombstone entries after save.
  /// [captureKind] is structural only — voice, typed, or typed_attach.
  static Future<void> onDurableSave({
    required int activeCountAfter,
    required String captureKind,
    DateTime? savedAt,
  }) async {
    final store = BetaAnalyticsTracker.milestoneStore;
    if (store == null) return;

    final now = (savedAt ?? DateTime.now()).toUtc();
    final normalizedKind = _normalizeCaptureKind(captureKind);

    var state = await store.read();

    if (activeCountAfter == 1) {
      if (!state.hasEmitted('first_moment_saved_local')) {
        state = state.copyWith(
          firstSaveAtUtc: now,
          saveCount: 1,
        );
        await store.write(state.markEmitted('first_moment_saved_local'));
        await BetaAnalyticsTracker.track(
          'first_moment_saved_local',
          parameters: {'capture_kind': normalizedKind},
        );
      }
      return;
    }

    state = state.copyWith(saveCount: activeCountAfter);
    if (state.firstSaveAtUtc == null) {
      // Repair state if first-save event was missed but count > 1.
      state = state.copyWith(firstSaveAtUtc: now);
    }
    await store.write(state);

    final firstSave = state.firstSaveAtUtc;
    if (firstSave == null) return;

    final elapsed = now.difference(firstSave);

    if (activeCountAfter == 2 && !state.hasEmitted('second_moment_saved_72h')) {
      final withinWindow = elapsed <= secondSaveWindow;
      await store.write(state.markEmitted('second_moment_saved_72h'));
      await BetaAnalyticsTracker.track(
        'second_moment_saved_72h',
        parameters: {'within_window': withinWindow ? 'true' : 'false'},
      );
    }

    if (activeCountAfter == 3 && !state.hasEmitted('third_moment_saved_7d')) {
      final withinWindow = elapsed <= thirdSaveWindow;
      await store.write(
        state
            .copyWith(saveCount: 3)
            .markEmitted('third_moment_saved_7d'),
      );
      await BetaAnalyticsTracker.track(
        'third_moment_saved_7d',
        parameters: {'within_window': withinWindow ? 'true' : 'false'},
      );
    }

    if (activeCountAfter >=
            EvidenceEligibilityPolicyConfig.possiblePatternMinimum &&
        !state.possiblePatternEligible &&
        !state.hasEmitted('possible_pattern_eligible')) {
      await store.update(
        (current) => current
            .copyWith(possiblePatternEligible: true)
            .markEmitted('possible_pattern_eligible'),
      );
      await BetaAnalyticsTracker.track(
        'possible_pattern_eligible',
        parameters: {
          'policy_version': EvidenceEligibilityPolicyConfig.policyVersion,
        },
      );
    }

    await BetaAnalyticsRetentionDeriver.evaluateAfterSave(
      store: store,
      activeCountAfter: activeCountAfter,
      now: now,
    );
  }

  static String _normalizeCaptureKind(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'voice':
        return 'voice';
      case 'typed_attach':
        return 'typed_attach';
      default:
        return 'typed';
    }
  }
}
