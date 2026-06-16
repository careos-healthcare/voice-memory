import 'archive_proof_counter_model.dart';
import 'pressure_check_in_record.dart';
import 'thread_return_evidence_engine.dart';

/// Builds the compact archive-proof counter from real local evidence only.
///
/// Pure and deterministic — counts come straight from the same thread
/// detection that powers Thread Return Evidence, so the proof counter can
/// never claim a connection the evidence cards would not show.
///
/// Visibility rules:
/// - A repeated thread (2+ connected entries) → connected count, return
///   count, and the "enough evidence to compare tomorrow" line.
/// - Right after a successful save ([savedToday]) → "one more piece" line,
///   even before a thread exists.
/// - Otherwise → nothing. No fabricated counts, no raw totals dressed up as
///   connection.
class ArchiveProofCounterEngine {
  const ArchiveProofCounterEngine();

  static const _threadEngine = ThreadReturnEvidenceEngine();

  /// [now] is injectable for tests and forwarded to thread detection.
  ArchiveProofCounter build(
    List<PressureCheckInRecord> records, {
    bool savedToday = false,
    DateTime? now,
  }) {
    final evidence = _threadEngine.build(records, now: now);

    if (!evidence.hasEvidence) {
      // Without a genuinely connected thread the only honest proof is the
      // save that just happened.
      if (!savedToday || records.isEmpty) return ArchiveProofCounter.none();
      return const ArchiveProofCounter(
        hasProof: true,
        onePieceLine: ArchiveProofCounter.onePieceTodayLine,
      );
    }

    final connected = evidence.occurrenceCount;
    // Returns are appearances after the first one.
    final returns = connected - 1;

    return ArchiveProofCounter(
      hasProof: true,
      connectedCount: connected,
      threadReturnCount: returns,
      connectedLine:
          'Your archive has $connected connected '
          '${connected == 1 ? 'recording' : 'recordings'}.',
      threadReturnLine:
          'This thread has returned $returns '
          '${returns == 1 ? 'time' : 'times'}.',
      readinessLine: ArchiveProofCounter.enoughEvidenceLine,
      onePieceLine: savedToday ? ArchiveProofCounter.onePieceTodayLine : '',
      entryIds: evidence.entryIds,
    );
  }
}
