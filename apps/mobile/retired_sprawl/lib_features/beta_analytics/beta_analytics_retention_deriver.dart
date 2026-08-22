import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_tracker.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_milestone_store.dart';

/// Derives retention metrics from local save timestamps — not optimistic emits.
abstract final class BetaAnalyticsRetentionDeriver {
  BetaAnalyticsRetentionDeriver._();

  static const Duration d7 = Duration(days: 7);
  static const Duration d30 = Duration(days: 30);

  /// Call after durable save or on app resume.
  static Future<void> evaluateAfterSave({
    required BetaAnalyticsMilestoneStore store,
    required int activeCountAfter,
    required DateTime now,
  }) async {
    if (activeCountAfter < 2) return;

    final state = await store.read();
    final firstSave = state.firstSaveAtUtc;
    if (firstSave == null) return;

    final cohortDay = now.difference(firstSave).inDays;

    if (cohortDay >= d7.inDays && !state.hasEmitted('retained_capture_d7')) {
      await store.write(state.markEmitted('retained_capture_d7'));
      await BetaAnalyticsTracker.track(
        'retained_capture_d7',
        parameters: {'cohort_day': cohortDay},
      );
    }

    if (cohortDay >= d30.inDays && !state.hasEmitted('retained_capture_d30')) {
      final refreshed = await store.read();
      if (refreshed.hasEmitted('retained_capture_d30')) return;
      await store.write(refreshed.markEmitted('retained_capture_d30'));
      await BetaAnalyticsTracker.track(
        'retained_capture_d30',
        parameters: {'cohort_day': cohortDay},
      );
    }
  }

  /// App-resume hook for users who saved a second moment later.
  static Future<void> evaluateOnResume(BetaAnalyticsMilestoneStore store) async {
    final state = await store.read();
    if (state.saveCount < 2 && state.firstSaveAtUtc == null) return;
    await evaluateAfterSave(
      store: store,
      activeCountAfter: state.saveCount.clamp(2, 9999),
      now: DateTime.now().toUtc(),
    );
  }
}
