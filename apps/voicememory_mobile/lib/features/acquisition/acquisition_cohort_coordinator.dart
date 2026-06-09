import '../../product/acquisition_start_copy.dart';
import '../../services/app_services.dart';
import '../activation/activation_tracker.dart';
import '../loop_mode/loop_mode_coordinator.dart';
import '../loop_mode/loop_mode_model.dart';
import '../quality/first_insight_specificity_store.dart';
import '../retention/retention_metrics_tracker.dart';
import 'acquisition_cohort_model.dart';
import 'acquisition_cohort_store.dart';

/// Assigns acquisition cohorts from deep links and tracks wedge funnel milestones.
abstract final class AcquisitionCohortCoordinator {
  AcquisitionCohortCoordinator._();

  static AcquisitionCohortStore _store() => AcquisitionCohortStore.instance();

  static Future<AcquisitionCohort?> load() async {
    if (!AppServices.isInitialized) return null;
    return _store().load();
  }

  static String promiseFor(AcquisitionCohortId cohortId) {
    switch (cohortId) {
      case AcquisitionCohortId.capacityYesDirect:
        return AcquisitionStartCopy.capacityTitle;
      case AcquisitionCohortId.proveEnoughDirect:
        return AcquisitionStartCopy.proveTitle;
      case AcquisitionCohortId.genericArchive:
        return AcquisitionStartCopy.genericTitle;
      case AcquisitionCohortId.unknown:
        return AcquisitionStartCopy.genericTitle;
    }
  }

  /// Parses `/start?loop=` / `/start?cohort=` and returns redirect path.
  static Future<String> resolveStartRedirect(Uri uri) async {
    final cohortParam = uri.queryParameters['cohort'];
    final loopParam = uri.queryParameters['loop'];

    AcquisitionCohortId? cohortId = AcquisitionCohortIdIds.fromId(cohortParam);
    cohortId ??= AcquisitionCohortIdIds.fromLoopParam(loopParam);

    if (cohortId == null) {
      await assign(
        cohortId: AcquisitionCohortId.proveEnoughDirect,
        source: 'deep_link_default',
        loopId: LoopModeIds.proveEnough,
      );
      return AcquisitionCohortId.proveEnoughDirect.startRoutePath;
    }

    await assign(
      cohortId: cohortId,
      source: 'deep_link_query',
      loopId: cohortId.defaultLoopId,
    );
    return cohortId.startRoutePath;
  }

  static Future<void> assignFromRoutePath(String path) async {
    AcquisitionCohortId cohortId;
    switch (path) {
      case '/start/capacity-yes':
        cohortId = AcquisitionCohortId.capacityYesDirect;
        break;
      case '/start/prove-enough':
        cohortId = AcquisitionCohortId.proveEnoughDirect;
        break;
      case '/start/generic':
        cohortId = AcquisitionCohortId.genericArchive;
        break;
      default:
        cohortId = AcquisitionCohortId.unknown;
    }
    await assign(
      cohortId: cohortId,
      source: 'start_route',
      loopId: cohortId.defaultLoopId,
    );
  }

  static Future<AcquisitionCohort> assign({
    required AcquisitionCohortId cohortId,
    required String source,
    String? loopId,
  }) async {
    final cohort = AcquisitionCohort(
      cohortId: cohortId,
      source: source,
      selectedLoopId: loopId ?? cohortId.defaultLoopId,
      promiseShown: promiseFor(cohortId),
      assignedAt: DateTime.now(),
    );
    await _store().save(cohort);
    ActivationTracker.trackCohortAssigned();
    if (loopId != null && loopId != LoopModeIds.notSure) {
      await LoopModeCoordinator.activate(loopId);
      ActivationTracker.trackCohortLoopSelected();
    }
    return cohort;
  }

  static Future<void> clear() async {
    if (!AppServices.isInitialized) return;
    await _store().clear();
  }

  /// Trial Control manual assignment.
  static Future<void> assignForTrial(AcquisitionCohortId cohortId) async {
    await assign(
      cohortId: cohortId,
      source: 'trial_control',
      loopId: cohortId.defaultLoopId,
    );
  }

  static Future<void> markStartScreenViewed(AcquisitionCohortId cohortId) async {
    final current = await load();
    if (current == null) {
      await assign(cohortId: cohortId, source: 'start_screen');
    }
    ActivationTracker.trackCohortStartScreenViewed();
  }

  static Future<void> markStartCtaTapped() async {
    final current = await load();
    if (current == null) return;
    await _store().save(
      current.copyWith(
        onboardingCompleted: true,
        promiseShown: current.promiseShown.isNotEmpty
            ? current.promiseShown
            : promiseFor(current.cohortId),
      ),
    );
    ActivationTracker.trackCohortStartCtaTapped();
  }

  static Future<void> markLoopSelected(String loopId) async {
    final current = await load();
    if (current == null) return;
    await _store().save(current.copyWith(selectedLoopId: loopId));
    ActivationTracker.trackCohortLoopSelected();
  }

  static Future<void> markFirstMomentRecorded() async {
    await _patch((c) => c.copyWith(firstMomentRecorded: true));
    ActivationTracker.trackCohortFirstMomentRecorded();
  }

  static Future<void> markSecondMomentRecorded() async {
    await _patch((c) => c.copyWith(secondMomentRecorded: true));
    ActivationTracker.trackCohortSecondMomentRecorded();
  }

  static Future<void> markThirdMomentRecorded() async {
    await _patch((c) => c.copyWith(thirdMomentRecorded: true));
    ActivationTracker.trackCohortThirdMomentRecorded();
  }

  static Future<void> markFirstReadAccepted() async {
    await _patch((c) => c.copyWith(firstReadAccepted: true));
  }

  static Future<void> markFirstReadRejected() async {
    await _patch((c) => c.copyWith(firstReadRejected: true));
  }

  static Future<void> markInsightSpecificity(
    FirstInsightSpecificityRating? rating,
  ) async {
    if (rating == null) return;
    await _patch((c) => c.copyWith(firstInsightSpecificityRating: rating));
  }

  static Future<void> markLoopReviewReached() async {
    await _patch((c) => c.copyWith(loopReviewReached: true));
    ActivationTracker.trackCohortReviewReached();
  }

  static Future<void> markLoopReviewConfirmed() async {
    await _patch((c) => c.copyWith(loopReviewConfirmed: true));
    ActivationTracker.trackCohortReviewConfirmed();
  }

  static Future<void> markPaywallTeaserShown() async {
    await _patch((c) => c.copyWith(paywallTeaserShown: true));
  }

  static Future<void> markPaywallTeaserTapped() async {
    await _patch((c) => c.copyWith(paywallTeaserTapped: true));
    ActivationTracker.trackCohortPaywallTeaserTapped();
  }

  static Future<void> syncMilestonesFromAppState() async {
    final current = await load();
    if (current == null) return;

    final specificity = await FirstInsightSpecificityStore.latest();
    final loop = await LoopModeCoordinator.loadActive();

    var updated = current;
    if (specificity != null &&
        updated.firstInsightSpecificityRating != specificity) {
      updated = updated.copyWith(firstInsightSpecificityRating: specificity);
    }
    if (loop?.readAccepted == true && !updated.firstReadAccepted) {
      updated = updated.copyWith(firstReadAccepted: true);
    }
    if (loop != null && updated.selectedLoopId != loop.id) {
      updated = updated.copyWith(selectedLoopId: loop.id);
    }

    await _store().save(updated);
  }

  /// Redirect cohort fast-path users away from broad onboarding.
  static Future<String?> fastPathRedirect(String path) async {
    final cohort = await load();
    if (cohort == null || !cohort.usesFastPath) return null;
    if (cohort.onboardingCompleted) return null;

    const allowed = {
      '/start/capacity-yes',
      '/start/prove-enough',
      '/start/generic',
      '/start',
      '/onboarding-loop',
    };
    if (cohort.onboardingCompleted && path == '/record') return null;
    if (allowed.contains(path) || path.startsWith('/entry/')) return null;

    if (path == '/onboarding' ||
        path == '/onboarding-intent' ||
        path == '/onboarding-loop') {
      return cohort.cohortId.startRoutePath;
    }

    return cohort.cohortId.startRoutePath;
  }

  static Future<void> _patch(
    AcquisitionCohort Function(AcquisitionCohort current) transform,
  ) async {
    final current = await load();
    if (current == null) return;
    await _store().save(transform(current));
  }
}
