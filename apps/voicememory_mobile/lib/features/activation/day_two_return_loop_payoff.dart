import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../retention/second_session_signal_engine.dart';

/// User-facing copy for the day-two / return loop payoff.
abstract final class DayTwoReturnLoopPayoffCopy {
  static const oneEntryBody = VisibleArchiveProofCopy.returnLoopOneEntryBody;

  static const twoEntryRelatedBody =
      VisibleArchiveProofCopy.returnLoopTwoEntryRelatedBody;

  static const twoEntryUnrelatedBody =
      VisibleArchiveProofCopy.returnLoopTwoEntryUnrelatedBody;

  static const twoEntryBody = VisibleArchiveProofCopy.returnLoopTwoEntryBody;

  static const threeEntryBody =
      VisibleArchiveProofCopy.returnLoopThreeEntryBody;

  static const primaryCta = VisibleArchiveProofCopy.returnLoopPrimaryCta;

  static const secondaryCta = VisibleArchiveProofCopy.returnLoopViewArchiveCta;
}

/// Calm return action after save — no streaks, guilt, or premature patterns.
class DayTwoReturnLoopPayoff {
  const DayTwoReturnLoopPayoff({
    required this.body,
    required this.primaryCta,
    required this.eligibleEntryCount,
    this.secondaryCta,
    this.offerReminder = false,
  });

  final String body;
  final String primaryCta;
  final String? secondaryCta;
  final int eligibleEntryCount;
  final bool offerReminder;
}

/// Deterministic return-loop payoff for the first three usable entries.
abstract final class DayTwoReturnLoopPayoffEngine {
  DayTwoReturnLoopPayoffEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  /// Returns null when there are no usable entries or more than three.
  static DayTwoReturnLoopPayoff? build({
    required List<JournalEntry> entries,
    bool reminderAvailable = false,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    return switch (eligible.length) {
      1 => DayTwoReturnLoopPayoff(
        body: DayTwoReturnLoopPayoffCopy.oneEntryBody,
        primaryCta: DayTwoReturnLoopPayoffCopy.primaryCta,
        eligibleEntryCount: 1,
        offerReminder: reminderAvailable,
      ),
      2 => DayTwoReturnLoopPayoff(
        body: _signalEngine.hasGroundedRepeatMatch(eligible)
            ? DayTwoReturnLoopPayoffCopy.twoEntryRelatedBody
            : DayTwoReturnLoopPayoffCopy.twoEntryUnrelatedBody,
        primaryCta: DayTwoReturnLoopPayoffCopy.primaryCta,
        secondaryCta: DayTwoReturnLoopPayoffCopy.secondaryCta,
        eligibleEntryCount: 2,
      ),
      _ => null,
    };
  }
}
