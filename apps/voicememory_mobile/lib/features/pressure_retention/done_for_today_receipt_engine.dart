import '../../features/archive_proof/visible_archive_proof_copy.dart';
import 'done_for_today_receipt_model.dart';
import 'one_small_recording_engine.dart';
import 'pressure_check_in_record.dart';
import 'thread_return_evidence_engine.dart';
import 'thread_return_evidence_model.dart';

/// Builds the post-save [DoneForTodayReceipt] — pure and deterministic,
/// no AI calls, no Pro requirement.
///
/// Rules:
/// - Only after a successful save ([saved] is false → no receipt).
/// - Thread terms come from the same source the pre-save prompt used
///   (guided thread plan first, then daily suggestion evidence) so the
///   receipt closes the loop the user just recorded on.
/// - With a thread term: "You added words to the work thread." and
///   "Tomorrow ArchiveMe can check whether this returned, faded, or changed."
/// - Without one: the generic affect label — "You added one piece today."
///   at a single entry, or a thread label once comparison is possible.
///   Tomorrow ArchiveMe can check whether it shows up again. Nothing
///   fabricated, nothing claimed beyond naming.
class DoneForTodayReceiptEngine {
  const DoneForTodayReceiptEngine();

  static const OneSmallRecordingEngine _sourceEngine =
      OneSmallRecordingEngine();
  static const ThreadReturnEvidenceEngine _threadEngine =
      ThreadReturnEvidenceEngine();

  /// [now] is injectable for tests and forwarded to the source engines.
  DoneForTodayReceipt build({
    required bool saved,
    required int entryCount,
    List<PressureCheckInRecord> records = const [],
    DateTime? now,
  }) {
    if (!saved) return DoneForTodayReceipt.none();

    final source = _sourceEngine.build(records, now: now);
    final terms = source.sourceTerms
        .take(DoneForTodayReceipt.maxTerms)
        .toList();
    final term = terms.isEmpty ? null : terms.first;
    final isSingleEntry = entryCount == 1;

    return DoneForTodayReceipt(
      hasReceipt: true,
      completionLine: 'That is enough for today.',
      // Light affect labeling: the user added words, using their own term
      // when one exists. Naming only — no processing or resolution claims.
      archiveLine: isSingleEntry
          ? VisibleArchiveProofCopy.oneEntryAddedTodayLine
          : term != null
          ? 'You added words to the $term thread.'
          : VisibleArchiveProofCopy.oneEntryAddedTodayLine,
      tomorrowLine: isSingleEntry
          ? VisibleArchiveProofCopy.oneEntryTomorrowLine
          : term != null
          ? 'Tomorrow ArchiveMe can check whether this returned, faded, '
                'or changed.'
          : VisibleArchiveProofCopy.oneEntryTomorrowLine,
      tomorrowCueTitle: DoneForTodayReceipt.defaultTomorrowCueTitle,
      tomorrowCueLine: _tomorrowCue(
        records,
        term,
        now,
        isSingleEntry: isSingleEntry,
      ),
      sourceTerms: terms,
      entryIds: source.entryIds,
    );
  }

  /// One concrete sentence shaped by where the thread currently stands —
  /// real status from the user's own evidence, never a daily obligation.
  String _tomorrowCue(
    List<PressureCheckInRecord> records,
    String? term,
    DateTime? now, {
    required bool isSingleEntry,
  }) {
    if (isSingleEntry) {
      return DoneForTodayReceipt.genericTomorrowCue;
    }
    final evidence = _threadEngine.build(records, now: now);
    if (evidence.hasEvidence && evidence.sourceTerms.isNotEmpty) {
      final threadTerm = evidence.sourceTerms.first;
      switch (evidence.status) {
        case ThreadReturnStatus.returned:
          return 'See whether the $threadTerm thread returned, faded, '
              'or changed.';
        case ThreadReturnStatus.building:
          return 'See whether the $threadTerm thread shows up again.';
        case ThreadReturnStatus.fading:
          return 'See whether the $threadTerm thread stays quieter.';
        case ThreadReturnStatus.earlySignal:
          return 'See whether this becomes a thread or fades out.';
      }
    }
    if (term != null) {
      return 'See whether the $term thread returned, faded, or changed.';
    }
    return DoneForTodayReceipt.genericTomorrowCue;
  }
}
