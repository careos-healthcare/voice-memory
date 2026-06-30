import '../../models/journal_entry.dart';
import '../early_archive/early_evidence_timeline_engine.dart';
import '../early_archive/early_first_signal_engine.dart';

/// When the Pro bridge may appear — only after the user has seen real value.
abstract class PaywallTimingGates {
  PaywallTimingGates._();

  /// Soft Pro bridge: never on first save, never without archive proof.
  static bool showSoftProBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool hasArchiveProof,
  }) =>
      entryCount >= 2 && hasArchiveProof && !resolved && !isPro;

  /// True when the archive has shown confirmed repeat, timeline, belief, or
  /// grounded pattern insight — not merely a second unrelated save.
  static bool hasArchiveProofFromEntries({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    bool hasBeliefProof = false,
    bool hasWeeklyReview = false,
    bool hasOhWowMoment = false,
  }) {
    if (entries.isEmpty) return false;

    final earlySignal = EarlyFirstSignalEngine.build(entries: entries);
    if (earlySignal?.kind == EarlyFirstSignalKind.twoEntryFirstSignal ||
        earlySignal?.kind == EarlyFirstSignalKind.threeEntryConfirmedRepeat) {
      return true;
    }

    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return true;
    }

    if (EarlyEvidenceTimelineEngine.build(
          entries: entries,
          triggerCapturedMilestone: triggerCapturedMilestone,
          helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
        ) !=
        null) {
      return true;
    }

    return hasBeliefProof || hasWeeklyReview || hasOhWowMoment;
  }
}
