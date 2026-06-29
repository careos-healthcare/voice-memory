import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import 'early_first_signal_copy.dart';

enum EarlyFirstSignalKind {
  oneEntryReceipt,
  twoEntryNoPattern,
  twoEntryFirstSignal,
}

/// User-facing early archive card — deterministic, no invented patterns.
class EarlyFirstSignalModel {
  const EarlyFirstSignalModel({
    required this.kind,
    required this.title,
    required this.lines,
    required this.primaryCta,
  });

  final EarlyFirstSignalKind kind;
  final String title;
  final List<String> lines;
  final String primaryCta;

  bool get showsPatternLanguage =>
      kind == EarlyFirstSignalKind.twoEntryFirstSignal;
}

abstract final class EarlyFirstSignalEngine {
  EarlyFirstSignalEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  /// Returns a card model for exactly 1 or 2 eligible entries; null otherwise.
  static EarlyFirstSignalModel? build({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length == 1) {
      return const EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.oneEntryReceipt,
        title: EarlyFirstSignalCopy.oneEntryTitle,
        lines: [
          EarlyFirstSignalCopy.oneEntryBody,
          EarlyFirstSignalCopy.notEnoughEvidence,
        ],
        primaryCta: EarlyFirstSignalCopy.addMomentCta,
      );
    }
    if (eligible.length != 2) return null;

    if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
      return const EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.twoEntryFirstSignal,
        title: EarlyFirstSignalCopy.twoEntryPatternStartTitle,
        lines: [
          EarlyFirstSignalCopy.twoEntryNoticedAgain,
          EarlyFirstSignalCopy.notEnoughEvidence,
          EarlyFirstSignalCopy.twoEntryConfirmRepeat,
        ],
        primaryCta: EarlyFirstSignalCopy.addMomentCta,
      );
    }

    return const EarlyFirstSignalModel(
      kind: EarlyFirstSignalKind.twoEntryNoPattern,
      title: EarlyFirstSignalCopy.twoEntryNoPatternTitle,
      lines: [EarlyFirstSignalCopy.twoEntryNoPatternBody],
      primaryCta: EarlyFirstSignalCopy.addMomentCta,
    );
  }
}
