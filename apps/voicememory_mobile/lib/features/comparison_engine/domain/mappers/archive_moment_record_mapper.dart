import '../../../archive_evidence/comparable_evidence_text.dart';
import '../../../../models/journal_entry.dart';
import '../models/archive_moment_record.dart';

abstract final class ArchiveMomentRecordMapper {
  ArchiveMomentRecordMapper._();

  static List<ArchiveMomentRecord> fromJournalEntries(
    List<JournalEntry> entries,
  ) {
    return [
      for (final entry in entries)
        ArchiveMomentRecord(
          id: entry.id,
          createdAt: entry.createdAt,
          savedWords: ComparableEvidenceText.userText(entry),
          parentThreadId: entry.archiveThreadId,
        ),
    ];
  }
}
