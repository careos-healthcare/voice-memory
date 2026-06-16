import 'archive_proof_counter_engine.dart';
import 'pressure_check_in_record.dart';
import 'shareable_archive_proof_model.dart';

/// Builds the privacy-safe share card. Pure and deterministic.
///
/// Privacy by construction: the share text is assembled only from counts
/// derived by the proof-counter engine. Record notes, evidence snippets,
/// source terms, and entry ids are never read into the output, so no private
/// text can leak — by default or by accident.
///
/// Variants:
/// - A connected thread (2+ entries) → "My archive connected N recordings."
///   plus the returned/tomorrow lines.
/// - Right after a save with no thread yet ([savedToday]) → the starter
///   variant. (The spec's "ArchiveMe found what kept returning" line is
///   intentionally not used here: nothing has returned yet, and the card
///   never overclaims.)
/// - Otherwise → nothing to share yet.
class ShareableArchiveProofEngine {
  const ShareableArchiveProofEngine();

  static const _counterEngine = ArchiveProofCounterEngine();

  /// [now] is injectable for tests and forwarded to thread detection.
  ShareableArchiveProof build(
    List<PressureCheckInRecord> records, {
    bool savedToday = false,
    DateTime? now,
  }) {
    final counter = _counterEngine.build(
      records,
      savedToday: savedToday,
      now: now,
    );

    if (counter.connectedCount >= 2) {
      return ShareableArchiveProof(
        hasProof: true,
        title: ShareableArchiveProof.defaultTitle,
        lines: [
          'My archive connected ${counter.connectedCount} recordings.',
          if (counter.threadReturnCount >= 1)
            ShareableArchiveProof.connectedReturnedLine,
          ShareableArchiveProof.connectedTomorrowLine,
        ],
        footer: ShareableArchiveProof.defaultFooter,
      );
    }

    if (savedToday && records.isNotEmpty) {
      return const ShareableArchiveProof(
        hasProof: true,
        title: ShareableArchiveProof.defaultTitle,
        lines: [
          ShareableArchiveProof.starterRecordedLine,
          ShareableArchiveProof.starterClosureLine,
        ],
        footer: ShareableArchiveProof.defaultFooter,
      );
    }

    return ShareableArchiveProof.none();
  }
}
