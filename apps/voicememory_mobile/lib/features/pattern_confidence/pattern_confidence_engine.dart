import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../belief_change/belief_change_moment_engine.dart';
import '../belief_change/belief_change_moment_model.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_store.dart';
import '../retention/second_session_signal_engine.dart';
import '../what_changed/what_changed_v2_model.dart';
import '../what_changed/what_changed_v2_store.dart';
import '../evidence_weighting/evidence_weighting_engine.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import 'pattern_confidence_copy.dart';
import 'pattern_confidence_model.dart';

/// Resolves evidence-strength labels from existing proof gates only.
abstract final class PatternConfidenceEngine {
  PatternConfidenceEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static PatternConfidence? build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    RepeatReturnCheckChangeProof? changeProof,
    bool viewingConfirmedRepeatOrTimeline = false,
    bool hideNotEnoughYet = false,
    bool helpfulActionCapturedMilestone = false,
  }) {
    if (_shouldUseNotEnoughYet(entries)) {
      if (hideNotEnoughYet) return null;
      return _confidence(PatternConfidenceState.notEnoughYet);
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length == 2 &&
        _signalEngine.hasGroundedRepeatMatch(eligible)) {
      return _confidence(PatternConfidenceState.earlySignal);
    }

    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      if (hideNotEnoughYet) return null;
      return _confidence(PatternConfidenceState.notEnoughYet);
    }

    if (_hasSofteningEvidence(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    )) {
      return _confidence(PatternConfidenceState.softeningPattern);
    }

    if (_hasChangingEvidence(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    )) {
      return _confidence(PatternConfidenceState.changingPattern);
    }

    if (ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) {
      return _confidence(PatternConfidenceState.repeatedPattern);
    }

    if (hideNotEnoughYet) return null;
    return _confidence(PatternConfidenceState.notEnoughYet);
  }

  static PatternConfidenceExplanationResult? buildExplanation({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    RepeatReturnCheckChangeProof? changeProof,
    bool viewingConfirmedRepeatOrTimeline = false,
    bool helpfulActionCapturedMilestone = false,
    DateTime? now,
  }) {
    if (_shouldUseNotEnoughYet(entries)) return null;

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);

    if (eligible.length == 2 &&
        _signalEngine.hasGroundedRepeatMatch(eligible)) {
      return _explanation(
        state: PatternConfidenceExplanationState.earlySignal,
        entries: entries,
        source: source,
        beliefSurfaceVisible: beliefSurfaceVisible,
        hasConfirmedRepeat: hasConfirmedRepeat,
      );
    }

    if (entries.length < 3) return null;
    if (!hasConfirmedRepeat && !beliefSurfaceVisible) return null;

    if (_hasChangingEvidence(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    )) {
      return _explanation(
        state: PatternConfidenceExplanationState.changed,
        entries: entries,
        source: source,
        beliefSurfaceVisible: beliefSurfaceVisible,
        hasConfirmedRepeat: hasConfirmedRepeat,
      );
    }

    if (_hasSofteningEvidence(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    )) {
      return _explanation(
        state: PatternConfidenceExplanationState.softened,
        entries: entries,
        source: source,
        beliefSurfaceVisible: beliefSurfaceVisible,
        hasConfirmedRepeat: hasConfirmedRepeat,
      );
    }

    final weighting = EvidenceWeightingEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      now: now,
    );
    if (weighting != null) {
      return _explanation(
        state: _explanationStateFromWeighting(weighting),
        entries: entries,
        source: source,
        beliefSurfaceVisible: beliefSurfaceVisible,
        hasConfirmedRepeat: hasConfirmedRepeat,
      );
    }

    if (hasConfirmedRepeat || beliefSurfaceVisible) {
      return _explanation(
        state: PatternConfidenceExplanationState.repeated,
        entries: entries,
        source: source,
        beliefSurfaceVisible: beliefSurfaceVisible,
        hasConfirmedRepeat: hasConfirmedRepeat,
      );
    }

    return null;
  }

  static bool shouldShowExplanation({
    required PatternConfidenceExplanationResult? result,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required int otherEducationCardCount,
    bool compact = false,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (compact && otherEducationCardCount > 0) return false;
    if (!compact &&
        !result.hasConfirmedRepeat &&
        !result.hasBeliefSurface &&
        result.confidenceState != PatternConfidenceExplanationState.earlySignal) {
      return false;
    }
    return true;
  }

  static bool shouldShowExplanationOnPatterns({
    required PatternConfidenceExplanationResult? result,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShowExplanation(
        result: result,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: false,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        otherEducationCardCount: 0,
      );

  static bool shouldShowExplanationOnRecordReady({
    required PatternConfidenceExplanationResult? result,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required int otherEducationCardCount,
  }) {
    if (result == null) return false;
    if (!result.hasConfirmedRepeat && !result.hasBeliefSurface) return false;
    return shouldShowExplanation(
      result: result,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: false,
      firstProofPayoffVisible: false,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      otherEducationCardCount: otherEducationCardCount,
      compact: true,
    );
  }

  static bool shouldShowExplanationOnWeeklyReview({
    required PatternConfidenceExplanationResult? result,
    required bool primaryPlacementVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      !primaryPlacementVisible &&
      shouldShowExplanation(
        result: result,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: false,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        otherEducationCardCount: 0,
        compact: true,
      );

  static int countOtherEducationCards({
    required bool captureFreedomLineVisible,
    required bool timelinePositioningVisible,
    required bool currentRelevanceVisible,
    required bool correctionMemoryVisible,
    required bool evidenceWeightingVisible,
    required bool proofSpecificityVisible,
    required bool presentDayRelevanceVisible,
  }) {
    var count = 0;
    if (captureFreedomLineVisible) count++;
    if (timelinePositioningVisible) count++;
    if (currentRelevanceVisible) count++;
    if (correctionMemoryVisible) count++;
    if (evidenceWeightingVisible) count++;
    if (proofSpecificityVisible) count++;
    if (presentDayRelevanceVisible) count++;
    return count;
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );

  static PatternConfidenceExplanationState _explanationStateFromWeighting(
    EvidenceWeightingResult weighting,
  ) {
    if (weighting.primaryState == EvidenceWeightState.needsFreshProof) {
      return PatternConfidenceExplanationState.needsFreshProof;
    }
    if (weighting.hasQuietSignal ||
        weighting.secondaryStates.contains(EvidenceWeightState.fading) ||
        weighting.primaryState == EvidenceWeightState.oldSignal) {
      return PatternConfidenceExplanationState.fading;
    }
    if (weighting.hasRecentEntry &&
        (weighting.primaryState == EvidenceWeightState.repeated ||
            weighting.primaryState == EvidenceWeightState.fresh)) {
      return PatternConfidenceExplanationState.current;
    }
    if (weighting.primaryState == EvidenceWeightState.repeated) {
      return PatternConfidenceExplanationState.repeated;
    }
    if (weighting.primaryState == EvidenceWeightState.fresh) {
      return weighting.hasConfirmedRepeat
          ? PatternConfidenceExplanationState.current
          : PatternConfidenceExplanationState.earlySignal;
    }
    return PatternConfidenceExplanationState.repeated;
  }

  static PatternConfidenceExplanationResult _explanation({
    required PatternConfidenceExplanationState state,
    required List<JournalEntry> entries,
    required String source,
    required bool beliefSurfaceVisible,
    required bool hasConfirmedRepeat,
  }) =>
      PatternConfidenceExplanationResult(
        shouldShow: true,
        entryCount: entries.length,
        source: source,
        hasConfirmedRepeat: hasConfirmedRepeat,
        hasBeliefSurface: beliefSurfaceVisible,
        confidenceState: state,
        title: PatternConfidenceCopy.explanationTitle,
        intro: PatternConfidenceCopy.explanationIntro,
        label: PatternConfidenceCopy.explanationLabelFor(state),
        body: PatternConfidenceCopy.explanationBodyFor(state),
        footer: PatternConfidenceCopy.explanationFooter,
        differentiationLine: PatternConfidenceCopy.explanationDifferentiation,
      );

  static bool _shouldUseNotEnoughYet(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsEarlySignals(entries)) return true;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return true;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return true;
    }
    if (ArchiveEvidenceQualityGate.showsWeakEvidenceFallback(entries)) {
      return true;
    }
    return false;
  }

  static bool _hasSofteningEvidence({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
    RepeatReturnCheckChangeProof? changeProof,
    required bool viewingConfirmedRepeatOrTimeline,
    bool helpfulActionCapturedMilestone = false,
  }) {
    final whatChanged = _latestWhatChangedMarker(entries);
    if (whatChanged == WhatChangedV2Option.softer) return true;

    final latestEntryId = RepeatReturnCheckStore.latestSavedEntryId(entries);
    final latestChoice = returnChecks
        .where((record) => record.entryId == latestEntryId)
        .map((record) => record.choice)
        .firstOrNull;
    if (latestChoice == RepeatReturnCheckChoice.softer) return true;

    if (EarlyFirstSignalEngine.hasSofteningReturnEvidence(entries)) return true;
    if (EarlyFirstSignalEngine.buildChangeNotice(entries: entries) != null) {
      return true;
    }

    final beliefChange = BeliefChangeMomentEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    return beliefChange?.changeType == BeliefChangeType.softened;
  }

  static bool _hasChangingEvidence({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
    RepeatReturnCheckChangeProof? changeProof,
    required bool viewingConfirmedRepeatOrTimeline,
    bool helpfulActionCapturedMilestone = false,
  }) {
    final beliefChange = BeliefChangeMomentEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    if (beliefChange == null) return false;
    return beliefChange.changeType != BeliefChangeType.softened;
  }

  static WhatChangedV2Option? _latestWhatChangedMarker(List<JournalEntry> entries) {
    final ids = entries.map((entry) => entry.id).toSet();
    final marker = WhatChangedV2Store.cached
        .where((record) => ids.contains(record.entryId))
        .firstOrNull;
    return marker?.option;
  }

  static PatternConfidence _confidence(PatternConfidenceState state) =>
      PatternConfidence(
        state: state,
        label: PatternConfidenceCopy.labelFor(state),
        body: PatternConfidenceCopy.bodyFor(state),
      );
}
