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
