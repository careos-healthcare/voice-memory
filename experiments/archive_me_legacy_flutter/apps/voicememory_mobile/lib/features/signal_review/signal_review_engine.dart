import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../loop_mode/capacity_loop_review_sections.dart';
import '../loop_mode/loop_mode_engine.dart';
import '../loop_mode/loop_mode_model.dart';
import '../post_save_insight/selected_signal_model.dart';
import '../post_save_insight/signal_feedback_model.dart';
import '../signal_journey/signal_journey_engine.dart';
import '../signal_journey/signal_journey_model.dart';
import 'signal_review_model.dart';

/// Builds signal reviews from journey evidence — conservative, no invented proof.
class SignalReviewEngine {
  const SignalReviewEngine();

  static const _journeyEngine = SignalJourneyEngine();
  static const _loopEngine = LoopModeEngine();
  static const _excerptMaxChars = 88;
  static const _minResolvedExcerpts = 2;

  /// Returns null when the journey has fewer than 3 supporting moments.
  SignalReview? build({
    required SignalJourney journey,
    required List<JournalEntry> entries,
    SelectedSignalRecord? selectedSignal,
    List<PostSaveSignalFeedback> feedback = const [],
    SignalReview? previous,
    LoopMode? activeLoop,
    DateTime? now,
  }) {
    if (journey.supportingCount < SignalJourneyEngine.defaultTargetEvidence) {
      return null;
    }

    final timestamp = now ?? DateTime.now();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final byId = {for (final e in eligible) e.id: e};

    final supportingExcerpts = <String>[];
    for (final id in journey.supportingMomentIds) {
      final entry = byId[id];
      if (entry == null) continue;
      final excerpt = _safeExcerpt(entry);
      if (excerpt.isNotEmpty) supportingExcerpts.add(excerpt);
    }

    final contradictingExcerpts = <String>[];
    for (final id in journey.contradictingMomentIds) {
      final entry = byId[id];
      if (entry == null) continue;
      final excerpt = _safeExcerpt(entry);
      if (excerpt.isNotEmpty) contradictingExcerpts.add(excerpt);
    }

    final weak = supportingExcerpts.length < _minResolvedExcerpts;
    final status = _statusFor(previous: previous, weak: weak);

    final loopSpecific = activeLoop?.isFullyImplementedLoop == true;

    if (weak) {
      return SignalReview(
        id: previous?.id ?? 'sr_${journey.id}',
        journeyId: journey.id,
        signalTitle: journey.signalTitle,
        reviewStatus: SignalReviewStatus.draft,
        evidenceCount: journey.supportingCount,
        whatRepeated: '',
        whatChanged: '',
        evidenceLines: const [],
        possibleContradictions: '',
        whatToWatchNext: '',
        nextEvidencePrompt: _nextPrompt(
          journey,
          selectedSignal,
          activeLoop: activeLoop,
        ),
        createdAt: previous?.createdAt ?? timestamp,
        updatedAt: timestamp,
        needsMoreEvidence: true,
        correctionTitle: previous?.correctionTitle,
        loopModeId: loopSpecific ? activeLoop!.id : previous?.loopModeId,
        loopTitle: loopSpecific ? activeLoop!.reviewTitle : previous?.loopTitle,
      );
    }

    if (activeLoop?.isCapacityYes == true) {
      return _loopReview(
        journey: journey,
        entries: entries,
        supportingExcerpts: supportingExcerpts,
        selectedSignal: selectedSignal,
        activeLoop: activeLoop!,
        previous: previous,
        status: status,
        timestamp: timestamp,
        sections: _loopEngine.buildCapacityReviewSections(
          journey: journey,
          entries: entries,
          promptRotation: journey.supportingCount,
        ),
        loopModeId: LoopModeIds.capacityYes,
      );
    }

    if (activeLoop?.isProveEnough == true) {
      return _loopReview(
        journey: journey,
        entries: entries,
        supportingExcerpts: supportingExcerpts,
        selectedSignal: selectedSignal,
        activeLoop: activeLoop!,
        previous: previous,
        status: status,
        timestamp: timestamp,
        sections: _loopEngine.buildProveEnoughReviewSections(
          journey: journey,
          entries: entries,
          promptRotation: journey.supportingCount,
        ),
        loopModeId: LoopModeIds.proveEnough,
      );
    }

    return SignalReview(
      id: previous?.id ?? 'sr_${journey.id}',
      journeyId: journey.id,
      signalTitle: previous?.correctionTitle?.trim().isNotEmpty == true
          ? previous!.correctionTitle!
          : journey.signalTitle,
      reviewStatus: status,
      evidenceCount: journey.supportingCount,
      whatRepeated: _whatRepeated(journey),
      whatChanged: _whatChanged(journey, contradictingExcerpts),
      evidenceLines: supportingExcerpts,
      possibleContradictions: _possibleContradictions(
        journey,
        contradictingExcerpts,
      ),
      whatToWatchNext: _watchNext(journey, selectedSignal),
      nextEvidencePrompt: _nextPrompt(journey, selectedSignal),
      createdAt: previous?.createdAt ?? timestamp,
      updatedAt: timestamp,
      needsMoreEvidence: false,
      correctionTitle: previous?.correctionTitle,
    );
  }

  /// 2–3 alternate pattern summaries from prior feedback — no invented reads.
  List<String> correctionAlternatives({
    required SignalReview review,
    required List<PostSaveSignalFeedback> feedback,
  }) {
    if (review.isCapacityLoopReview) {
      return _loopEngine.capacityCorrectionAlternatives();
    }
    if (review.isProveEnoughLoopReview) {
      return _loopEngine.proveEnoughCorrectionAlternatives();
    }

    final current = review.signalTitle.trim().toLowerCase();
    final seen = <String>{};
    final alts = <String>[];

    void add(String title) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (key == current || seen.contains(key)) return;
      seen.add(key);
      alts.add(trimmed);
    }

    for (final row in feedback.reversed) {
      if (row.action == PostSaveSignalAction.rejected ||
          row.action == PostSaveSignalAction.abChoiceNeither ||
          row.action == PostSaveSignalAction.anotherAngleShown) {
        add(row.signalTitle);
      }
      if (row.action == PostSaveSignalAction.accepted) {
        add(row.signalTitle);
      }
      if (alts.length >= 3) break;
    }

    return alts.take(3).toList();
  }

  String statusLabel(SignalReviewStatus status) {
    switch (status) {
      case SignalReviewStatus.draft:
        return ConsumerUiCopy.signalReviewStatusDraft;
      case SignalReviewStatus.ready:
        return ConsumerUiCopy.signalReviewStatusReady;
      case SignalReviewStatus.confirmed:
        return ConsumerUiCopy.signalReviewStatusConfirmed;
      case SignalReviewStatus.corrected:
        return ConsumerUiCopy.signalReviewStatusCorrected;
      case SignalReviewStatus.watching:
        return ConsumerUiCopy.signalReviewStatusWatching;
    }
  }

  SignalReviewStatus _statusFor({
    required SignalReview? previous,
    required bool weak,
  }) {
    if (weak) return SignalReviewStatus.draft;
    if (previous == null) return SignalReviewStatus.ready;
    switch (previous.reviewStatus) {
      case SignalReviewStatus.confirmed:
      case SignalReviewStatus.corrected:
      case SignalReviewStatus.watching:
        return previous.reviewStatus;
      case SignalReviewStatus.draft:
      case SignalReviewStatus.ready:
        return SignalReviewStatus.ready;
    }
  }

  String _whatRepeated(SignalJourney journey) {
    return ConsumerUiCopy.signalReviewRepeatedTemplate
        .replaceAll('{title}', journey.signalTitle)
        .replaceAll('{count}', journey.supportingCount.toString());
  }

  String _whatChanged(SignalJourney journey, List<String> contradicting) {
    if (journey.contradictingMomentIds.isEmpty) {
      return ConsumerUiCopy.signalReviewChangedNone;
    }
    if (contradicting.isNotEmpty) {
      return ConsumerUiCopy.signalReviewChangedWithEvidence;
    }
    return ConsumerUiCopy.signalReviewChangedSome;
  }

  String _possibleContradictions(
    SignalJourney journey,
    List<String> contradictingExcerpts,
  ) {
    final parts = <String>[];
    final challenge = journey.wouldChallenge?.trim() ?? '';
    if (challenge.isNotEmpty) {
      parts.add(challenge);
    }
    for (final excerpt in contradictingExcerpts.take(2)) {
      parts.add('“$excerpt”');
    }
    if (parts.isEmpty) {
      return ConsumerUiCopy.signalReviewContradictionsDefault;
    }
    return parts.join(' ');
  }

  String _watchNext(SignalJourney journey, SelectedSignalRecord? signal) {
    if (journey.nextPrompt.trim().isNotEmpty) return journey.nextPrompt;
    final confirm =
        signal?.wouldConfirm?.trim() ?? journey.wouldConfirm?.trim();
    if (confirm != null && confirm.isNotEmpty) return confirm;
    return _journeyEngine.completionWatchNext(journey);
  }

  SignalReview _loopReview({
    required SignalJourney journey,
    required List<JournalEntry> entries,
    required List<String> supportingExcerpts,
    required SelectedSignalRecord? selectedSignal,
    required LoopMode activeLoop,
    required SignalReview? previous,
    required SignalReviewStatus status,
    required DateTime timestamp,
    required CapacityLoopReviewSections sections,
    required String loopModeId,
  }) {
    return SignalReview(
      id: previous?.id ?? 'sr_${journey.id}',
      journeyId: journey.id,
      signalTitle: previous?.correctionTitle?.trim().isNotEmpty == true
          ? previous!.correctionTitle!
          : journey.signalTitle,
      reviewStatus: status,
      evidenceCount: journey.supportingCount,
      whatRepeated: sections.whatRepeated,
      whatChanged: sections.whatChanged,
      evidenceLines: supportingExcerpts,
      possibleContradictions: sections.whatWouldProveThisWrong,
      whatToWatchNext: sections.nextYesPrompt,
      nextEvidencePrompt: sections.nextYesPrompt,
      createdAt: previous?.createdAt ?? timestamp,
      updatedAt: timestamp,
      needsMoreEvidence: false,
      correctionTitle: previous?.correctionTitle,
      loopModeId: loopModeId,
      loopTitle: sections.loopTitle,
      reviewSubtitle: sections.subtitle,
      whatItSeemedToCost: sections.whatItSeemedToCost,
      commonTrigger: sections.commonTrigger,
      whatWouldProveThisWrong: sections.whatWouldProveThisWrong,
      reviewConfidenceLabel: sections.reviewConfidenceLabel,
    );
  }

  String _nextPrompt(
    SignalJourney journey,
    SelectedSignalRecord? signal, {
    LoopMode? activeLoop,
  }) {
    if (activeLoop?.isFullyImplementedLoop == true) {
      return _loopEngine.nextPrompt(
        activeLoop!,
        rotation: journey.supportingCount,
      );
    }
    final fromSignal = signal?.nextPrompt.trim() ?? '';
    if (fromSignal.isNotEmpty) return fromSignal;
    if (journey.nextPrompt.trim().isNotEmpty) return journey.nextPrompt;
    return ConsumerUiCopy.signalReviewNextEvidenceDefault;
  }

  String _safeExcerpt(JournalEntry entry) {
    final summary = entry.reflectionSummary.trim();
    if (summary.length >= 12) {
      return _truncate(summary);
    }
    final transcript = entry.transcript.trim();
    if (transcript.length >= ArchiveEvidenceGuard.minimumTranscriptChars) {
      return _truncate(transcript);
    }
    return '';
  }

  String _truncate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _excerptMaxChars) return cleaned;
    return '${cleaned.substring(0, _excerptMaxChars - 1).trim()}…';
  }
}
