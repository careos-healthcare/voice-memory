import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../belief_change/belief_change_moment_engine.dart';
import '../belief_change/belief_change_moment_model.dart';
import '../quiet_signal/quiet_signal_engine.dart';
import '../come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/helpful_action_appeared_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../retention/second_session_signal_engine.dart';
import '../what_changed/what_changed_v2_model.dart';
import '../what_changed/what_changed_v2_store.dart';
import 'pattern_lifecycle_copy.dart';
import 'pattern_lifecycle_model.dart';

/// Resolves pattern lifecycle from existing engines only — no new thresholds.
abstract final class PatternLifecycleEngine {
  PatternLifecycleEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static const _priority = <PatternLifecycleState>[
    PatternLifecycleState.softening,
    PatternLifecycleState.changing,
    PatternLifecycleState.quiet,
    PatternLifecycleState.watching,
    PatternLifecycleState.repeated,
    PatternLifecycleState.forming,
  ];

  static PatternLifecycle? build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    RepeatReturnCheckChangeProof? changeProof,
    bool viewingConfirmedRepeatOrTimeline = false,
    bool helpfulActionCapturedMilestone = false,
    EarlyFirstSignalModel? confirmedRepeat,
    DateTime? now,
  }) {
    if (_shouldHide(entries)) return null;

    final state = _resolveState(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      confirmedRepeat: confirmedRepeat,
      now: now,
    );
    if (state == null) return null;

    return PatternLifecycle(
      state: state,
      label: PatternLifecycleCopy.labelFor(state),
      body: PatternLifecycleCopy.bodyFor(state),
    );
  }

  static PatternLifecycleState? _resolveState({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
    RepeatReturnCheckChangeProof? changeProof,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool helpfulActionCapturedMilestone,
    EarlyFirstSignalModel? confirmedRepeat,
    DateTime? now,
  }) {
    final candidates = <PatternLifecycleState>{};
    if (_isSoftening(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    )) {
      candidates.add(PatternLifecycleState.softening);
    }
    if (_isChanging(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    )) {
      candidates.add(PatternLifecycleState.changing);
    }
    if (_isQuiet(entries: entries, now: now)) {
      candidates.add(PatternLifecycleState.quiet);
    }
    if (_isWatching(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    )) {
      candidates.add(PatternLifecycleState.watching);
    }
    if (_isRepeated(entries)) {
      candidates.add(PatternLifecycleState.repeated);
    }
    if (_isForming(entries)) {
      candidates.add(PatternLifecycleState.forming);
    }

    for (final state in _priority) {
      if (candidates.contains(state)) return state;
    }
    return null;
  }

  static bool _shouldHide(List<JournalEntry> entries) {
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

  static bool _isForming(List<JournalEntry> entries) {
    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return false;
    }
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    return eligible.length == 2 &&
        _signalEngine.hasGroundedRepeatMatch(eligible);
  }

  static bool _isRepeated(List<JournalEntry> entries) =>
      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);

  static bool _isWatching({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool helpfulActionCapturedMilestone,
  }) =>
      ComeBackTomorrowV2Store.hasActive;

  static bool _isQuiet({
    required List<JournalEntry> entries,
    DateTime? now,
  }) =>
      QuietSignalEngine.build(entries: entries, now: now) != null;

  static bool _isSoftening({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
    RepeatReturnCheckChangeProof? changeProof,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool helpfulActionCapturedMilestone,
  }) {
    final whatChanged = _latestWhatChangedMarker(entries);
    if (whatChanged == WhatChangedV2Option.softer) return true;

    final beliefChange = BeliefChangeMomentEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    return beliefChange?.changeType == BeliefChangeType.softened ||
        beliefChange?.changeType == BeliefChangeType.lowerUrgency;
  }

  static bool _isChanging({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
    RepeatReturnCheckChangeProof? changeProof,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool helpfulActionCapturedMilestone,
  }) {
    final whatChanged = _latestWhatChangedMarker(entries);
    if (whatChanged == WhatChangedV2Option.differentResponse) return true;

    final beliefChange = BeliefChangeMomentEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      changeProof: changeProof,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    if (beliefChange?.changeType == BeliefChangeType.differentResponse) {
      return true;
    }
    if (beliefChange?.changeType == BeliefChangeType.helpfulAction) {
      return true;
    }

    return HelpfulActionAppearedEngine.build(
          entries: entries,
          returnChecks: returnChecks,
          helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
        ) !=
        null;
  }

  static WhatChangedV2Option? _latestWhatChangedMarker(
    List<JournalEntry> entries,
  ) {
    final ids = entries.map((entry) => entry.id).toSet();
    final marker = WhatChangedV2Store.cached
        .where((record) => ids.contains(record.entryId))
        .firstOrNull;
    return marker?.option;
  }
}
