import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/archive_packs/archive_pack.dart';
import 'package:archiveme_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Export one archive pack's entries to markdown.
class PackArchiveExport {
  const PackArchiveExport();

  static const _statusEngine = ArchiveEntrySearchEngine();

  static String fileName(DateTime now) {
    final local = now.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'archiveme-pack-export-${local.year}-$month-$day.md';
  }

  String buildMarkdown({
    required ArchivePack pack,
    required List<JournalEntry> packEntries,
    List<PressureCheckInRecord> records = const [],
    List<ArchiveFact> facts = const [],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final recordsByEntryId = {for (final r in records) r.entryId: r};
    final entries = [...packEntries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final buffer = StringBuffer()
      ..writeln('# Pack ${pack.name}')
      ..writeln()
      ..writeln('Export date: ${formatUserFacingDate(clock)}')
      ..writeln('Entries: ${entries.length}');

    if (pack.instructions.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Instructions')
        ..writeln()
        ..writeln(pack.instructions.trim());
    }

    if (facts.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Saved details')
        ..writeln();
      for (final fact in facts) {
        final type = FactType.fromId(fact.factType);
        buffer
          ..writeln('### ${fact.label.trim()}')
          ..writeln()
          ..writeln('- Type: ${type.label}')
          ..writeln('- Value: ${fact.value.trim()}');
        if (fact.note.trim().isNotEmpty) {
          buffer.writeln('- Note: ${fact.note.trim()}');
        }
        buffer.writeln();
      }
    }

    buffer
      ..writeln()
      ..writeln('## Entries');

    for (final entry in entries) {
      final record = recordsByEntryId[entry.id];
      final status = _statusEngine.memoryStatusFor(
        entry,
        record,
        records,
        clock,
      );
      buffer
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln('### ${timelineEntryTitle(entry)}')
        ..writeln()
        ..writeln('- Recorded: ${formatUserFacingDate(entry.createdAt)}')
        ..writeln('- Memory status: ${status.label}')
        ..writeln()
        ..writeln(entry.transcript.trim());
    }

    return buffer.toString();
  }
}