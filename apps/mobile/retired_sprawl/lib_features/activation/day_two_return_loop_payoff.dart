import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// User-facing copy for the day-two / return loop payoff.
abstract final class DayTwoReturnLoopPayoffCopy {
  static const String oneEntryBody = VisibleArchiveProofCopy.returnLoopOneEntryBody;

  static const String twoEntryRelatedBody =
      VisibleArchiveProofCopy.returnLoopTwoEntryRelatedBody;

  static const String twoEntryUnrelatedBody =
      VisibleArchiveProofCopy.returnLoopTwoEntryUnrelatedBody;

  static const String twoEntryBody = VisibleArchiveProofCopy.returnLoopTwoEntryBody;

  static const String threeEntryBody =
      VisibleArchiveProofCopy.returnLoopThreeEntryBody;

  static const String primaryCta = VisibleArchiveProofCopy.returnLoopPrimaryCta;

  static const String secondaryCta = VisibleArchiveProofCopy.returnLoopViewArchiveCta;
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