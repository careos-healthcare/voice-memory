import 'package:archiveme_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:archiveme_mobile/features/prove_enough/monthly_ambition_pressure_review_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/monthly_ambition_pressure_review_model.dart';
import 'package:archiveme_mobile/features/prove_enough/monthly_ambition_pressure_review_store.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_contradiction_store.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Loads monthly prove_enough review data and access rules.
abstract class MonthlyAmbitionPressureReviewCoordinator {
  MonthlyAmbitionPressureReviewCoordinator._();

  static const _engine = MonthlyAmbitionPressureReviewEngine();

  static Future<MonthlyAmbitionPressureReview> load({DateTime? now}) async {
    if (!AppServices.isInitialized) {
      return _emptyReview(now);
    }

    final entries = await AppServices.instance.journalStore.loadAll();
    final contradictions = await ProveEnoughContradictionStore.instance()
        .loadAll();
    final loop = await LoopModeCoordinator.loadActive();
    if (loop?.isProveEnough != true) {
      return _engine.build(entries: entries, now: now);
    }

    return _engine.build(
      entries: entries,
      contradictions: contradictions,
      now: now,
    );
  }

  static Future<bool> canViewFullReview(
    PremiumEntitlements? entitlements,
  ) async {
    if (entitlements?.isPro == true) return true;
    if (!AppServices.isInitialized) return true;
    return !(await MonthlyAmbitionPressureReviewStore.instance()
        .freeReviewConsumed());
  }

  static Future<void> consumeFreeReviewIfNeeded(
    PremiumEntitlements? entitlements,
  ) async {
    if (entitlements?.isPro == true || !AppServices.isInitialized) return;
    final consumed = await MonthlyAmbitionPressureReviewStore.instance()
        .freeReviewConsumed();
    if (!consumed) {
      await MonthlyAmbitionPressureReviewStore.instance().markFreeReviewUsed();
    }
  }

  static MonthlyAmbitionPressureReview _emptyReview(DateTime? now) {
    return _engine.build(entries: const [], now: now);
  }
}