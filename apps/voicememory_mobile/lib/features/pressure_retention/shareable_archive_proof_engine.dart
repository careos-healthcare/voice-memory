import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../demo/sample_archive_mode.dart';
import 'archive_proof_counter_engine.dart';
import 'pressure_check_in_record.dart';
import 'shareable_archive_proof_model.dart';

/// Builds the privacy-safe share card. Pure and deterministic.
///
/// Privacy by construction: share text uses fixed product lines and eligible
/// entry counts only. Transcripts, evidence snippets, names, and entry ids are
/// never read into the output.
class ShareableArchiveProofEngine {
  const ShareableArchiveProofEngine();

  static const _counterEngine = ArchiveProofCounterEngine();
  static const _minJournalEligibleCount = 3;

  /// Journal activation loop — eligible usable entries only, never snippets.
  ShareableArchiveProof buildFromJournal({
    required List<JournalEntry> entries,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final eligibleCount =
        ArchiveEvidenceGuard.eligibleReflectionCount(realEntries);
    if (eligibleCount < _minJournalEligibleCount) {
      return ShareableArchiveProof.none();
    }
    return _proofForEligibleCount(eligibleCount);
  }

  /// Pressure-check-in path — counts from thread detection only.
  ShareableArchiveProof build(
    List<PressureCheckInRecord> records, {
    bool savedToday = false,
    int entryCount = 0,
    DateTime? now,
  }) {
    final counter = _counterEngine.build(
      records,
      savedToday: savedToday,
      now: now,
    );

    if (counter.connectedCount >= 2) {
      final variant = counter.connectedCount >= 3
          ? ShareableArchiveProof.variantC
          : ShareableArchiveProof.variantB;
      return _proof([variant]);
    }

    if (entryCount >= _minJournalEligibleCount &&
        savedToday &&
        records.isNotEmpty) {
      return _proofForEligibleCount(entryCount);
    }

    return ShareableArchiveProof.none();
  }

  static ShareableArchiveProof _proofForEligibleCount(int eligibleCount) {
    if (eligibleCount >= 5) {
      return _proof([ShareableArchiveProof.variantC]);
    }
    if (eligibleCount == 4) {
      return _proof([ShareableArchiveProof.variantA]);
    }
    if (eligibleCount >= 3) {
      return _proof([ShareableArchiveProof.variantB]);
    }
    return ShareableArchiveProof.none();
  }

  static ShareableArchiveProof _proof(List<String> lines) {
    return ShareableArchiveProof(
      hasProof: true,
      title: ShareableArchiveProof.defaultTitle,
      subtitle: ShareableArchiveProof.defaultSubtitle,
      lines: lines,
    );
  }
}
