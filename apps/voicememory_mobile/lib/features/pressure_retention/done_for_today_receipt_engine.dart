import 'done_for_today_receipt_model.dart';
import 'one_small_recording_engine.dart';
import 'pressure_check_in_record.dart';

/// Builds the post-save [DoneForTodayReceipt] — pure and deterministic,
/// no AI calls, no Pro requirement.
///
/// Rules:
/// - Only after a successful save ([saved] is false → no receipt).
/// - Thread terms come from the same source the pre-save prompt used
///   (guided thread plan first, then daily suggestion evidence) so the
///   receipt closes the loop the user just recorded on.
/// - With a thread term: "You added evidence to the work thread." and
///   "ArchiveMe can check whether this returned, faded, or changed."
/// - Without one: generic archive language — one more piece, connected
///   with future recordings if it shows up again. Nothing fabricated.
class DoneForTodayReceiptEngine {
  const DoneForTodayReceiptEngine();

  static const OneSmallRecordingEngine _sourceEngine =
      OneSmallRecordingEngine();

  /// [now] is injectable for tests and forwarded to the source engines.
  DoneForTodayReceipt build({
    required bool saved,
    List<PressureCheckInRecord> records = const [],
    DateTime? now,
  }) {
    if (!saved) return DoneForTodayReceipt.none();

    final source = _sourceEngine.build(records, now: now);
    final terms =
        source.sourceTerms.take(DoneForTodayReceipt.maxTerms).toList();
    final term = terms.isEmpty ? null : terms.first;

    return DoneForTodayReceipt(
      hasReceipt: true,
      completionLine: 'Today\u2019s recording is saved.',
      archiveLine: term != null
          ? 'You added evidence to the $term thread.'
          : 'You added one more piece to your archive.',
      tomorrowLine: term != null
          ? 'ArchiveMe can check whether this returned, faded, or changed. '
              'Come back tomorrow if you want to see what changed.'
          : 'ArchiveMe can connect this with future recordings if it shows '
              'up again. Come back tomorrow if you want to see what changed.',
      sourceTerms: terms,
      entryIds: source.entryIds,
    );
  }
}
