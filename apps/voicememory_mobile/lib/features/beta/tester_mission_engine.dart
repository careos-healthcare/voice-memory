import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../retention/second_session_signal_engine.dart';
import 'tester_mission_copy.dart';
import 'tester_mission_model.dart';

/// Builds the beta tester mission card from entry count and local evidence.
abstract final class TesterMissionEngine {
  TesterMissionEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static TesterMissionResult build({
    required int entryCount,
    required List<JournalEntry> entries,
    required bool compactAtEntryZero,
  }) {
    final presentation = compactAtEntryZero && entryCount == 0
        ? TesterMissionPresentation.compact
        : TesterMissionPresentation.full;

    if (entryCount <= 0) {
      return TesterMissionResult(
        title: TesterMissionCopy.title,
        body: TesterMissionCopy.entry0Body,
        stepLabel: TesterMissionCopy.entry0StepLabel,
        footer: TesterMissionCopy.entry0Footer,
        step: TesterMissionStep.step1Of3,
        presentation: presentation,
        entryCount: entryCount,
      );
    }

    if (entryCount == 1) {
      return TesterMissionResult(
        title: TesterMissionCopy.title,
        body: TesterMissionCopy.entry1Body,
        stepLabel: TesterMissionCopy.entry1StepLabel,
        footer: TesterMissionCopy.entry1Footer,
        step: TesterMissionStep.step2Of3,
        presentation: presentation,
        entryCount: entryCount,
      );
    }

    if (entryCount == 2) {
      final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
      if (eligible.length == 2 &&
          _signalEngine.hasGroundedRepeatMatch(eligible)) {
        return TesterMissionResult(
          title: TesterMissionCopy.title,
          body: TesterMissionCopy.entry2RelatedBody,
          stepLabel: TesterMissionCopy.entry2RelatedStepLabel,
          footer: TesterMissionCopy.entry2RelatedFooter,
          step: TesterMissionStep.step3Of3,
          presentation: presentation,
          entryCount: entryCount,
        );
      }

      return TesterMissionResult(
        title: TesterMissionCopy.title,
        body: TesterMissionCopy.entry2UnrelatedBody,
        stepLabel: TesterMissionCopy.entry2UnrelatedStepLabel,
        footer: TesterMissionCopy.entry2UnrelatedFooter,
        step: TesterMissionStep.stillLooking,
        presentation: presentation,
        entryCount: entryCount,
      );
    }

    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return TesterMissionResult(
        title: TesterMissionCopy.title,
        body: TesterMissionCopy.entry3ConfirmedBody,
        stepLabel: TesterMissionCopy.entry3ConfirmedStepLabel,
        footer: TesterMissionCopy.entry3ConfirmedFooter,
        step: TesterMissionStep.firstProofReached,
        presentation: presentation,
        entryCount: entryCount,
      );
    }

    return TesterMissionResult(
      title: TesterMissionCopy.title,
      body: TesterMissionCopy.entry3UnconfirmedBody,
      stepLabel: TesterMissionCopy.entry3UnconfirmedStepLabel,
      footer: TesterMissionCopy.entry3UnconfirmedFooter,
      step: TesterMissionStep.stillLooking,
      presentation: presentation,
      entryCount: entryCount,
    );
  }
}
