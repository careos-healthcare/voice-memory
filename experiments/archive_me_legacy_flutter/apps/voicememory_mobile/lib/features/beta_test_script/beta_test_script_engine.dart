import '../../models/journal_entry.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../beta_feedback/beta_feedback_store.dart';
import '../first_proof_payoff/first_proof_payoff_engine.dart';
import '../first_proof_truth/first_proof_truth_store.dart';
import 'beta_test_script_copy.dart';
import 'beta_test_script_model.dart';
import 'beta_test_script_store.dart';

/// Visibility gates for beta-only tester script surfaces.
abstract final class BetaTestScriptGates {
  BetaTestScriptGates._();

  static bool get isBetaEnabled => ArchiveBetaMissionGate.isEnabled;

  static bool shouldShowOnTestingScreen() => isBetaEnabled;

  static bool shouldShowCompactCardOnRecord({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool dismissed,
    required bool showReturnDayFlow,
    required bool firstProofLoopActive,
    required bool showWhatChangedV2Display,
  }) {
    if (!isBetaEnabled || dismissed) return false;
    if (!isReady || isRecording) return false;
    if (isPostSave && (firstProofLoopActive || showWhatChangedV2Display)) {
      return false;
    }
    if (showReturnDayFlow) return false;
    if (firstProofLoopActive && !isPostSave) return false;
    return true;
  }
}

/// Builds beta tester script content from local safe counters only.
abstract final class BetaTestScriptEngine {
  BetaTestScriptEngine._();

  static BetaTestScriptPlan buildPlan({
    required List<JournalEntry> entries,
    BetaTestScriptProgressRecord? storeRecord,
  }) {
    final progress = buildProgressSummary(entries: entries);
    return BetaTestScriptPlan(
      title: BetaTestScriptCopy.screenTitle,
      intro: BetaTestScriptCopy.intro,
      days: [
        const BetaTestScriptDayPlan(
          stepKey: 'day_1',
          title: BetaTestScriptCopy.day1Title,
          body: BetaTestScriptCopy.day1Body,
          checklist: BetaTestScriptCopy.day1Checklist,
        ),
        const BetaTestScriptDayPlan(
          stepKey: 'day_2',
          title: BetaTestScriptCopy.day2Title,
          body: BetaTestScriptCopy.day2Body,
          checklist: BetaTestScriptCopy.day2Checklist,
        ),
        const BetaTestScriptDayPlan(
          stepKey: 'day_3',
          title: BetaTestScriptCopy.day3Title,
          body: BetaTestScriptCopy.day3Body,
          checklist: BetaTestScriptCopy.day3Checklist,
        ),
      ],
      successHeading: BetaTestScriptCopy.successHeading,
      successQuestions: BetaTestScriptCopy.successQuestions,
      failureHeading: BetaTestScriptCopy.failureHeading,
      progress: progress,
    );
  }

  static BetaTestScriptProgressSummary buildProgressSummary({
    required List<JournalEntry> entries,
  }) {
    final entryCount = entries.length;
    final firstProofReached = _hasFirstProofReached(entries);
    final truthAnswered = _hasFirstProofTruthAnswered(entries);
    final feedbackSent = _hasFeedbackSent();

    final day1Status = entryCount >= 1
        ? BetaTestScriptRowStatus.done
        : BetaTestScriptRowStatus.notStarted;
    final day1Label = entryCount >= 1
        ? BetaTestScriptCopy.day1Done
        : BetaTestScriptCopy.day1NotStarted;

    final day2Status = entryCount >= 2
        ? BetaTestScriptRowStatus.done
        : BetaTestScriptRowStatus.waiting;
    final day2Label = entryCount >= 2
        ? BetaTestScriptCopy.day2Done
        : BetaTestScriptCopy.day2Waiting;

    final day3Status = entryCount >= 3
        ? BetaTestScriptRowStatus.done
        : BetaTestScriptRowStatus.waiting;
    final day3Label = entryCount >= 3
        ? BetaTestScriptCopy.day3Done
        : BetaTestScriptCopy.day3Waiting;

    final firstProofStatus = firstProofReached
        ? BetaTestScriptRowStatus.reached
        : BetaTestScriptRowStatus.notReached;
    final firstProofLabel = firstProofReached
        ? BetaTestScriptCopy.firstProofReached
        : BetaTestScriptCopy.firstProofNotReached;

    final feedbackStatus = feedbackSent
        ? BetaTestScriptRowStatus.sent
        : BetaTestScriptRowStatus.notSent;
    final feedbackLabel = feedbackSent
        ? BetaTestScriptCopy.feedbackSent
        : BetaTestScriptCopy.feedbackNotSent;

    return BetaTestScriptProgressSummary(
      day1Status: day1Status,
      day1Label: day1Label,
      day2Status: day2Status,
      day2Label: day2Label,
      day3Status: day3Status,
      day3Label: day3Label,
      firstProofStatus: firstProofStatus,
      firstProofLabel: firstProofLabel,
      feedbackStatus: feedbackStatus,
      feedbackLabel: feedbackLabel,
      entryCount: entryCount,
      firstProofReached: firstProofReached,
      firstProofTruthAnswered: truthAnswered,
      feedbackSent: feedbackSent,
      showSendFeedbackSecondary: truthAnswered || firstProofReached,
    );
  }

  static BetaTestScriptCompactCard? buildCompactCard({
    required List<JournalEntry> entries,
  }) {
    if (!BetaTestScriptGates.isBetaEnabled) return null;
    if (BetaTestScriptStore.cached.dismissed) return null;

    final progress = buildProgressSummary(entries: entries);
    final phase = _compactPhase(
      entryCount: progress.entryCount,
      firstProofReached: progress.firstProofReached,
      truthAnswered: progress.firstProofTruthAnswered,
    );
    final body = switch (phase) {
      BetaTestScriptCompactPhase.day1 => BetaTestScriptCopy.compactBodyDay1,
      BetaTestScriptCompactPhase.day2 => BetaTestScriptCopy.compactBodyDay2,
      BetaTestScriptCompactPhase.day3 => BetaTestScriptCopy.compactBodyDay3,
      BetaTestScriptCompactPhase.firstProofReached =>
        BetaTestScriptCopy.compactBodyFirstProof,
      BetaTestScriptCompactPhase.complete =>
        BetaTestScriptCopy.compactBodyComplete,
    };

    return BetaTestScriptCompactCard(
      title: BetaTestScriptCopy.compactTitle,
      body: body,
      phase: phase,
      showSendFeedbackSecondary: progress.showSendFeedbackSecondary,
    );
  }

  static BetaTestScriptCompactPhase _compactPhase({
    required int entryCount,
    required bool firstProofReached,
    required bool truthAnswered,
  }) {
    if (truthAnswered) return BetaTestScriptCompactPhase.complete;
    if (firstProofReached) return BetaTestScriptCompactPhase.firstProofReached;
    return switch (entryCount) {
      0 => BetaTestScriptCompactPhase.day1,
      1 => BetaTestScriptCompactPhase.day2,
      _ => BetaTestScriptCompactPhase.day3,
    };
  }

  static bool _hasFirstProofReached(List<JournalEntry> entries) =>
      entries.length >= 3 &&
      FirstProofPayoffEngine.build(entries: entries) != null;

  static bool _hasFirstProofTruthAnswered(List<JournalEntry> entries) {
    final proofKey = FirstProofTruthStore.proofKeyForFirstProof(entries);
    return proofKey.isNotEmpty && FirstProofTruthStore.hasAnswered(proofKey);
  }

  static bool _hasFeedbackSent() => BetaFeedbackStore.cached.hasResponse;
}
