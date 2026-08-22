import 'package:archiveme_mobile/features/post_save_insight/selected_signal_model.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_engine.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_store.dart';
import 'package:archiveme_mobile/features/signal_review/signal_review_coordinator.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Input when a user accepts a saved read.
class SignalJourneyAcceptInput {
  const SignalJourneyAcceptInput({
    required this.signalId,
    required this.signalTitle,
    required this.nextPrompt,
    this.readId,
    this.categoryId,
    this.entryId,
    this.wouldConfirm,
    this.wouldChallenge,
    this.evidenceSummary,
  });

  factory SignalJourneyAcceptInput.fromSelected(SelectedSignalRecord record) {
    return SignalJourneyAcceptInput(
      signalId: record.id,
      signalTitle: record.title,
      nextPrompt: record.nextPrompt,
      readId: record.readId,
      categoryId: record.categoryId,
      entryId: record.entryId,
      wouldConfirm: record.wouldConfirm,
      wouldChallenge: record.wouldContradict,
      evidenceSummary: record.evidenceUsed,
    );
  }

  final String signalId;
  final String signalTitle;
  final String nextPrompt;
  final String? readId;
  final String? categoryId;
  final String? entryId;
  final String? wouldConfirm;
  final String? wouldChallenge;
  final String? evidenceSummary;
}

/// Orchestrates signal journey lifecycle — create, update, reject, archive.
abstract class SignalJourneyCoordinator {
  SignalJourneyCoordinator._();

  static const _engine = SignalJourneyEngine();

  static SignalJourneyStore _store() => SignalJourneyStore.instance();

  static Future<SignalJourney?> loadActive() async {
    if (!AppServices.isInitialized) return null;
    final journey = await _store().loadActive();
    if (journey == null) return null;
    if (journey.status == SignalJourneyStatus.archived) return null;
    return journey;
  }

  static Future<List<SignalJourney>> loadHistory() async {
    if (!AppServices.isInitialized) return const [];
    return _store().loadHistory();
  }

  static Future<int> completedJourneyCount() async {
    if (!AppServices.isInitialized) return 0;
    return _store().completedJourneyCount();
  }

  static Future<SignalJourney?> onSignalAccepted(
    SignalJourneyAcceptInput input,
  ) async {
    if (!AppServices.isInitialized) return null;
    final now = DateTime.now();
    final existing = await _store().loadActive();

    SignalJourney journey;
    if (existing != null &&
        _engine.matchesSignal(
          existing,
          signalId: input.signalId,
          readId: input.readId,
          categoryId: input.categoryId,
          signalTitle: input.signalTitle,
        )) {
      journey = _appendSupport(existing, input.entryId, now);
    } else if (existing != null && existing.isActive) {
      await _store().archiveToHistory(existing);
      journey = _newJourney(input, now);
    } else {
      journey = _newJourney(input, now);
    }

    journey = _recompute(journey, now);
    await _store().saveActive(journey);
    await SignalReviewCoordinator.maybeRefreshFromJourney(journey);
    return journey;
  }

  static Future<SignalJourney?> onSignalRejected({
    required String signalId,
    String? readId,
    String? categoryId,
    String? signalTitle,
    String? entryId,
  }) async {
    if (!AppServices.isInitialized) return null;
    final existing = await _store().loadActive();
    if (existing == null) return null;
    if (!_engine.matchesSignal(
      existing,
      signalId: signalId,
      readId: readId,
      categoryId: categoryId,
      signalTitle: signalTitle,
    )) {
      return existing;
    }

    final now = DateTime.now();
    final contradicting = List<String>.from(existing.contradictingMomentIds);
    if (entryId != null && !contradicting.contains(entryId)) {
      contradicting.add(entryId);
    }

    final journey = _recompute(
      existing.copyWith(
        rejectedReadCount: existing.rejectedReadCount + 1,
        contradictingMomentIds: contradicting,
        contradictionCount: contradicting.length,
        updatedAt: now,
      ),
      now,
    );
    await _store().saveActive(journey);
    await SignalReviewCoordinator.maybeRefreshFromJourney(journey);
    return journey;
  }

  static Future<SignalJourney?> acknowledgeCompletion() async {
    if (!AppServices.isInitialized) return null;
    final journey = await _store().loadActive();
    if (journey == null) return null;
    final updated = journey.copyWith(
      completionAcknowledged: true,
      updatedAt: DateTime.now(),
    );
    await _store().saveActive(updated);
    return updated;
  }

  static Future<SignalJourney?> archiveActive() async {
    if (!AppServices.isInitialized) return null;
    final journey = await _store().loadActive();
    if (journey == null) return null;
    final archived = journey.copyWith(
      status: SignalJourneyStatus.archived,
      updatedAt: DateTime.now(),
    );
    await _store().archiveToHistory(archived);
    await _store().clearActive();
    return archived;
  }

  static Future<bool> shouldGateLongTermArchive({
    required PremiumEntitlements? entitlements,
  }) async {
    if (entitlements?.isPro == true) return false;
    final completed = await completedJourneyCount();
    return completed >= 1;
  }

  static SignalJourney _newJourney(
    SignalJourneyAcceptInput input,
    DateTime now,
  ) {
    final supporting = <String>[];
    if (input.entryId != null) supporting.add(input.entryId!);
    return SignalJourney(
      id: '${now.millisecondsSinceEpoch}_${input.signalId}',
      signalId: input.signalId,
      signalTitle: input.signalTitle,
      status: SignalJourneyStatus.collectingEvidence,
      evidenceCount: supporting.length,
      targetEvidenceCount: SignalJourneyEngine.defaultTargetEvidence,
      acceptedReadCount: 1,
      rejectedReadCount: 0,
      contradictionCount: 0,
      startedAt: now,
      updatedAt: now,
      nextPrompt: input.nextPrompt,
      readId: input.readId,
      categoryId: input.categoryId,
      wouldConfirm: input.wouldConfirm,
      wouldChallenge: input.wouldChallenge,
      evidenceSummary: input.evidenceSummary,
      supportingMomentIds: supporting,
    );
  }

  static SignalJourney _appendSupport(
    SignalJourney existing,
    String? entryId,
    DateTime now,
  ) {
    final supporting = List<String>.from(existing.supportingMomentIds);
    if (entryId != null && !supporting.contains(entryId)) {
      supporting.add(entryId);
    }
    return existing.copyWith(
      acceptedReadCount: existing.acceptedReadCount + 1,
      supportingMomentIds: supporting,
      evidenceCount: supporting.length,
      updatedAt: now,
    );
  }

  static SignalJourney _recompute(SignalJourney journey, DateTime now) {
    final status = _engine.statusFor(
      supportingCount: journey.supportingMomentIds.length,
      contradictionCount: journey.contradictingMomentIds.length,
      archived: journey.status == SignalJourneyStatus.archived,
    );
    return journey.copyWith(
      status: status,
      evidenceCount: journey.supportingMomentIds.length,
      contradictionCount: journey.contradictingMomentIds.length,
      updatedAt: now,
    );
  }
}