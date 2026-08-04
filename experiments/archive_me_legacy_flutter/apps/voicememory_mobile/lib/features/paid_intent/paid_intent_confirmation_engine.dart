import '../../models/journal_entry.dart';
import '../capacity_loop/capacity_loop_engine.dart';
import '../capacity_loop/capacity_three_moment_gates.dart';
import '../demo/sample_archive_mode.dart';
import 'paid_intent_confirmation_copy.dart';
import 'paid_intent_confirmation_models.dart';

/// Builds paid intent confirmation visibility from local value signals.
class PaidIntentConfirmationEngine {
  const PaidIntentConfirmationEngine({
    this.loopEngine = const CapacityLoopEngine(),
  });

  final CapacityLoopEngine loopEngine;

  PaidIntentConfirmationResult build(PaidIntentConfirmationInput input) {
    if (input.sampleMode ||
        input.screenshotMode ||
        input.realSavedMomentCount <= 0) {
      return PaidIntentConfirmationResult.hidden;
    }

    if (!input.capacityWedgeActive) {
      return PaidIntentConfirmationResult.hidden;
    }

    final record = input.record;
    if (record?.isComplete == true) {
      if (record!.isAnswered) {
        return PaidIntentConfirmationResult(
          showCard: false,
          showOnWeeklyReview: false,
          showOnSupportLink: true,
          title: PaidIntentConfirmationCopy.title,
          body: PaidIntentConfirmationCopy.body,
          question: PaidIntentConfirmationCopy.question,
          primaryCtaLabel: PaidIntentConfirmationCopy.saveAnswerCta,
          secondaryCtaLabel: PaidIntentConfirmationCopy.skipForNowCta,
          answeredSummaryLine: PaidIntentConfirmationCopy.answeredSummaryLine(
            record.responseId,
          ),
          responseOptions: PaidIntentConfirmationCopy.responseOptionLabels(),
        );
      }
      return PaidIntentConfirmationResult.hidden;
    }

    if (!_isEligible(input)) {
      return PaidIntentConfirmationResult.hidden;
    }

    return PaidIntentConfirmationResult(
      showCard: true,
      showOnWeeklyReview: true,
      showOnSupportLink: true,
      title: PaidIntentConfirmationCopy.title,
      body: PaidIntentConfirmationCopy.body,
      question: PaidIntentConfirmationCopy.question,
      primaryCtaLabel: PaidIntentConfirmationCopy.saveAnswerCta,
      secondaryCtaLabel: PaidIntentConfirmationCopy.skipForNowCta,
      answeredSummaryLine: '',
      responseOptions: PaidIntentConfirmationCopy.responseOptionLabels(),
    );
  }

  static bool _isEligible(PaidIntentConfirmationInput input) {
    if (input.capacityMomentCount < CapacityThreeMomentGates.activationTarget) {
      return false;
    }
    if (!input.fitIsPositive) return false;
    if (!input.dailyChangeShown) return false;
    if (!input.hasReturnSignal) return false;
    return true;
  }

  static bool returnedByDay7Signal({
    required List<JournalEntry> realEntries,
    DateTime? now,
  }) {
    if (realEntries.length >= 7) return true;
    if (realEntries.isEmpty) return false;
    final sorted = [...realEntries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first.createdAt;
    final reference = now ?? DateTime.now();
    return reference.difference(first).inDays >= 7;
  }

  static PaidIntentValueSignalsAtResponse valueSignalsFrom({
    required int capacityMomentCount,
    required String fitResponseLabel,
    required bool dailyChangeAvailable,
    required bool weeklyReviewAvailable,
    required bool boundaryResponseSelected,
  }) {
    return PaidIntentValueSignalsAtResponse(
      capacityMomentCount: capacityMomentCount,
      fitResponse: fitResponseLabel,
      dailyChangeAvailable: dailyChangeAvailable,
      weeklyReviewAvailable: weeklyReviewAvailable,
      boundaryResponseSelected: boundaryResponseSelected,
    );
  }

  PaidIntentConfirmationResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool capacityLoopActive,
    required bool capacityCohortActive,
    required bool fitIsPositive,
    required String fitResponseLabel,
    required bool dailyChangeShown,
    required bool weeklyReviewAvailable,
    required bool boundaryResponseSelected,
    required bool screenshotMode,
    PaidIntentConfirmationRecord? record,
    bool sampleMode = false,
    DateTime? now,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    if (sampleMode || (entries.isNotEmpty && realEntries.isEmpty)) {
      return PaidIntentConfirmationResult.hidden;
    }

    final momentCount = loopEngine.eligibleCapacityEntryIds(realEntries).length;

    return build(
      PaidIntentConfirmationInput(
        sampleMode: false,
        screenshotMode: screenshotMode,
        capacityWedgeActive: capacityLoopActive || capacityCohortActive,
        capacityMomentCount: momentCount,
        realSavedMomentCount: realEntries.length,
        fitIsPositive: fitIsPositive,
        fitResponseLabel: fitResponseLabel,
        dailyChangeShown: dailyChangeShown,
        weeklyReviewAvailable: weeklyReviewAvailable,
        returnedByDay7: returnedByDay7Signal(
          realEntries: realEntries,
          now: now,
        ),
        boundaryResponseSelected: boundaryResponseSelected,
        record: record,
      ),
    );
  }
}
