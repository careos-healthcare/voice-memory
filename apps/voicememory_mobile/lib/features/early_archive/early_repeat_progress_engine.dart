import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import 'early_repeat_progress_copy.dart';
import 'early_repeat_progress_model.dart';

/// Builds the early repeat progress card for entryCount 1–2.
abstract final class EarlyRepeatProgressEngine {
  EarlyRepeatProgressEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static EarlyRepeatProgressResult? build({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty || eligible.length > 2) return null;

    if (eligible.length == 1) {
      return const EarlyRepeatProgressResult(
        kind: EarlyRepeatProgressKind.oneMoment,
        title: EarlyRepeatProgressCopy.oneMomentTitle,
        body: EarlyRepeatProgressCopy.oneMomentBody,
        progressLabel: EarlyRepeatProgressCopy.oneMomentProgress,
      );
    }

    if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
      return const EarlyRepeatProgressResult(
        kind: EarlyRepeatProgressKind.twoRelated,
        title: EarlyRepeatProgressCopy.twoRelatedTitle,
        body: EarlyRepeatProgressCopy.twoRelatedBody,
        progressLabel: EarlyRepeatProgressCopy.twoRelatedProgress,
      );
    }

    return const EarlyRepeatProgressResult(
      kind: EarlyRepeatProgressKind.twoUnrelated,
      title: EarlyRepeatProgressCopy.twoUnrelatedTitle,
      body: EarlyRepeatProgressCopy.twoUnrelatedBody,
      progressLabel: EarlyRepeatProgressCopy.twoUnrelatedProgress,
    );
  }
}
