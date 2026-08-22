import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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