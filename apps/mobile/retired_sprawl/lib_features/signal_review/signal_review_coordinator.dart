import 'dart:async';

import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_store.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_store.dart';
import 'package:archiveme_mobile/features/post_save_insight/selected_signal_coordinator.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_coordinator.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_store.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_contradiction_store.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_coordinator.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:archiveme_mobile/features/signal_review/signal_review_engine.dart';
import 'package:archiveme_mobile/features/signal_review/signal_review_model.dart';
import 'package:archiveme_mobile/features/signal_review/signal_review_store.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/product/loop_mode_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Orchestrates signal review creation and user actions.
abstract class SignalReviewCoordinator {
  SignalReviewCoordinator._();

  static const _engine = SignalReviewEngine();

  static SignalReviewStore _store() => SignalReviewStore.instance();

  static Future<SignalReview?> loadActive() async {
    if (!AppServices.isInitialized) return null;
    return _store().loadActive();
  }

  static Future<SignalReview?> loadForJourney(String journeyId) async {
    if (!AppServices.isInitialized) return null;
    return _store().loadForJourney(journeyId);
  }

  static Future<SignalReview?> loadForActiveJourney() async {
    if (!AppServices.isInitialized) return null;
    final journey = await SignalJourneyCoordinator.loadActive();
    if (journey == null) return null;
    return maybeRefreshFromJourney(journey);
  }

  static Future<SignalReview?> maybeRefreshFromJourney(
    SignalJourney journey,
  ) async {
    if (!AppServices.isInitialized) return null;
    if (journey.supportingCount < 3) return null;

    final entries = await AppServices.instance.journalStore.loadAll();
    final selected = await SelectedSignalCoordinator.loadCurrent();
    final feedback = await SignalFeedbackStore.instance().loadAll();
    final previous = await _store().loadForJourney(journey.id);
    final activeLoop = await LoopModeCoordinator.loadActive();

    final review = _engine.build(
      journey: journey,
      entries: entries,
      selectedSignal: selected,
      feedback: feedback,
      previous: previous,
      activeLoop: activeLoop,
    );
    if (review == null) return null;

    final enriched = await ProveEnoughContradictionStore.instance()
        .enrichReviewChallengeEvidence(review);
    await _store().saveActive(enriched);
    return enriched;
  }

  static Future<SignalReview?> confirm({required String reviewId}) async {
    if (!AppServices.isInitialized) return null;
    final current = await _store().loadActive();
    if (current == null || current.id != reviewId) return current;

    final now = DateTime.now();
    final wasConfirmed = current.reviewStatus == SignalReviewStatus.confirmed;
    final updated = current.copyWith(
      reviewStatus: SignalReviewStatus.confirmed,
      updatedAt: now,
    );
    await _store().saveActive(updated);
    if (!wasConfirmed) {
      await _store().incrementConfirmedCount();
      await _savePatternMemory(updated);
      await LoopModeCoordinator.markCompleted();
      if (updated.isLoopSpecificReview) {
        ActivationTracker.trackLoopReviewConfirmed();
        unawaited(AcquisitionCohortCoordinator.markLoopReviewConfirmed());
        if (updated.loopModeId == LoopModeIds.proveEnough) {
          ActivationTracker.trackProveReviewConfirmed();
        }
      }
    }
    return updated;
  }

  static Future<SignalReview?> correct({
    required String reviewId,
    required String alternativeTitle,
    String? signalId,
    String? categoryId,
  }) async {
    if (!AppServices.isInitialized) return null;
    final current = await _store().loadActive();
    if (current == null || current.id != reviewId) return current;

    final trimmed = alternativeTitle.trim();
    if (trimmed.isEmpty) return current;

    final journey = await SignalJourneyCoordinator.loadActive();
    if (journey != null) {
      await SignalFeedbackCoordinator.track(
        action: PostSaveSignalAction.rejected,
        signalId: signalId ?? journey.signalId,
        signalTitle: current.signalTitle,
        categoryId: categoryId ?? journey.categoryId,
      );
      await SignalFeedbackCoordinator.track(
        action: PostSaveSignalAction.accepted,
        signalId: signalId ?? journey.signalId,
        signalTitle: trimmed,
        categoryId: categoryId ?? journey.categoryId,
      );
    }

    final now = DateTime.now();
    final updated = current.copyWith(
      reviewStatus: SignalReviewStatus.corrected,
      signalTitle: trimmed,
      correctionTitle: trimmed,
      updatedAt: now,
    );
    await _store().saveActive(updated);
    if (updated.isLoopSpecificReview) {
      ActivationTracker.trackLoopReviewCorrected();
    }
    return updated;
  }

  static Future<SignalReview?> keepWatching({required String reviewId}) async {
    if (!AppServices.isInitialized) return null;
    final current = await _store().loadActive();
    if (current == null || current.id != reviewId) return current;

    final journey = await SignalJourneyCoordinator.loadActive();
    final activeLoop = await LoopModeCoordinator.loadActive();
    var prompt = current.nextEvidencePrompt.trim().isNotEmpty
        ? current.nextEvidencePrompt
        : journey?.nextPrompt ?? '';

    if (current.isLoopSpecificReview && activeLoop != null) {
      final loopEngine = LoopModeCoordinator.engine();
      prompt = loopEngine.nextPrompt(
        activeLoop,
        rotation: (journey?.supportingCount ?? 0) + 1,
      );
      await LoopModeStore.instance().save(
        activeLoop.copyWith(activePrompt: prompt, updatedAt: DateTime.now()),
      );
    }

    final now = DateTime.now();
    final updated = current.copyWith(
      reviewStatus: SignalReviewStatus.watching,
      nextEvidencePrompt: prompt,
      whatToWatchNext: prompt.isNotEmpty ? prompt : current.whatToWatchNext,
      updatedAt: now,
    );
    await _store().saveActive(updated);
    await SignalJourneyCoordinator.acknowledgeCompletion();
    if (updated.isLoopSpecificReview) {
      ActivationTracker.trackLoopReviewKeptWatching();
    }
    return updated;
  }

  static Future<void> markViewed(SignalReview review) async {
    if (!review.isLoopSpecificReview) return;
    ActivationTracker.trackLoopReviewViewed();
    unawaited(AcquisitionCohortCoordinator.markLoopReviewReached());
  }

  static Future<bool> shouldShowLoopPaywallTeaser({
    required SignalReview? review,
    required PremiumEntitlements? entitlements,
  }) async {
    if (review == null || !review.isLoopSpecificReview) return false;
    if (review.reviewStatus != SignalReviewStatus.confirmed) return false;
    if (entitlements?.isPro == true) return false;
    return !(await _store().loopPaywallTeaserDismissed());
  }

  static Future<void> dismissLoopPaywallTeaser() async {
    if (!AppServices.isInitialized) return;
    await _store().dismissLoopPaywallTeaser();
  }

  static String confirmBannerFor(SignalReview review) {
    if (review.isLoopSpecificReview) return LoopModeCopy.reviewConfirmSaved;
    return '';
  }

  static String keepWatchingBannerFor(SignalReview review) {
    if (review.isLoopSpecificReview) {
      return LoopModeCopy.reviewKeepWatchingSaved;
    }
    return '';
  }

  static Future<int> confirmedReviewCount() async {
    if (!AppServices.isInitialized) return 0;
    return _store().confirmedReviewCount();
  }

  /// After the first confirmed review, deeper archive surfaces may paywall.
  static Future<bool> shouldGatePremiumArchive({
    required PremiumEntitlements? entitlements,
  }) async {
    if (entitlements?.isPro == true) return false;
    final confirmed = await confirmedReviewCount();
    return confirmed >= 1;
  }

  static Future<void> _savePatternMemory(SignalReview review) async {
    final store = PatternMemoryStore(AppServices.instance.prefs);
    final update = PatternMemoryUpdate(
      checkInId: review.id,
      resultHint: PatternMemoryResultHint.same,
      reflectionText: review.whatRepeated,
      createdAt: DateTime.now(),
    );
    await store.applyUpdate(update, patternTitle: review.signalTitle);
  }
}