import '../../design/user_facing_date.dart';
import 'archive_fact.dart';

/// Markdown export of user-selected saved details.
///
/// The user chose to export, so label/value/note may appear in the file.
/// Analytics never sees the exported text.
class FactLedgerExport {
  const FactLedgerExport();

  static String fileName(DateTime now) {
    final local = now.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'archiveme-details-${local.year}-$month-$day.md';
  }

  String buildMarkdown({required List<ArchiveFact> facts, DateTime? now}) {
    final clock = now ?? DateTime.now();
    final buffer = StringBuffer()
      ..writeln('# ArchiveMe details')
      ..writeln()
      ..writeln('Export date: ${formatUserFacingDate(clock)}')
      ..writeln('Details: ${facts.length}');

    for (final fact in facts) {
      final type = FactType.fromId(fact.factType);
      buffer
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln('## ${fact.label.trim()}')
        ..writeln()
        ..writeln('- Type: ${type.label}')
        ..writeln('- Updated: ${formatUserFacingDate(fact.updatedAt)}');
      if (fact.isPinned) buffer.writeln('- Pinned');
      buffer
        ..writeln()
        ..writeln('**Value**')
        ..writeln()
        ..writeln(fact.value.trim());
      if (fact.note.trim().isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('**Note**')
          ..writeln()
          ..writeln(fact.note.trim());
      }
    }

    return buffer.toString();
  }

  /// Linked facts for one selected entry export block.
  static void writeEntryFacts(StringBuffer buffer, List<ArchiveFact> facts) {
    for (final fact in facts) {
      final type = FactType.fromId(fact.factType);
      buffer
        ..writeln('- ${FactLedgerCopy.exportSavedDetailPrefix}: ${type.label}')
        ..writeln('- Label: ${fact.label.trim()}')
        ..writeln('- Value: ${fact.value.trim()}');
      if (fact.note.trim().isNotEmpty) {
        buffer.writeln('- Note: ${fact.note.trim()}');
      }
    }
  }
}
