import '../../design/user_facing_date.dart';
import '../../models/journal_entry.dart';
import '../archive_search/archive_entry_search_engine.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import '../timeline/timeline_entry_display.dart';
import '../memory/curated_memory_marker.dart';
import '../memory/curated_memory_preservation_policy.dart';
import '../memory/entry_aboutness.dart';
import '../memory/memory_surfacing_mode.dart';
import '../action_items/action_item_filter.dart';
import '../action_items/archive_action_item.dart';
import '../fact_ledger/archive_fact.dart';
import '../fact_ledger/fact_ledger_export.dart';
import '../fact_ledger/fact_ledger_filter.dart';
import 'archive_export_format.dart';

/// Builds an export of explicitly selected entries — and only those.
///
/// The user chose to export, so the export may contain their entry
/// text. It contains nothing else: no internal ids, sync state, audio
/// paths, account/session data, app-lock data, or analytics ids — and
/// no unselected entries. Analytics never sees the exported text.
class SelectedArchiveExport {
  const SelectedArchiveExport();

  static const String failureMessage =
      'Export couldn’t be completed. Check file access in Settings, then try again.';

  static const _statusEngine = ArchiveEntrySearchEngine();

  /// Safe export filename: archiveme-export-YYYY-MM-DD plus extension.
  static String fileName(
    DateTime now, {
    ArchiveExportFormat format = ArchiveExportFormat.markdown,
  }) {
    final local = now.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'archiveme-export-${local.year}-$month-$day'
        '.${format.fileExtension}';
  }

  /// Markdown for the selected entries only, newest first.
  String buildMarkdown({
    required List<JournalEntry> selectedEntries,
    List<PressureCheckInRecord> records = const [],
    List<ArchiveActionItem> actionItems = const [],
    List<ArchiveFact> facts = const [],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final recordsByEntryId = {for (final r in records) r.entryId: r};
    final entries = [...selectedEntries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final buffer = StringBuffer()
      ..writeln('# ArchiveMe export')
      ..writeln()
      ..writeln('Export date: ${formatUserFacingDate(clock)}')
      ..writeln('Entries: ${entries.length}');

    for (final entry in entries) {
      final record = recordsByEntryId[entry.id];
      final status = _statusEngine.memoryStatusFor(
        entry,
        record,
        records,
        clock,
      );
      final tags =
          record?.contexts.map((c) => c.label).toList() ?? const <String>[];
      final isExact =
          entry.keepExactDetails || (record?.keepExactDetails ?? false);
      final isPreserved =
          CuratedMemoryMarker.matchesPreservedFilter(entry) ||
          (record != null &&
              CuratedMemoryPreservationPolicy.isPreservedRecord(record));

      buffer
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln('## ${timelineEntryTitle(entry)}')
        ..writeln()
        ..writeln('- Recorded: ${formatUserFacingDate(entry.createdAt)}');
      if (tags.isNotEmpty) {
        buffer.writeln('- Context tags: ${tags.join(', ')}');
      }
      if (entry.isPinned) buffer.writeln('- Pinned');
      if (isExact) buffer.writeln('- Exact evidence');
      if (isPreserved) {
        buffer.writeln(
          '- ${CuratedMemoryCopy.exportLabel}: ${CuratedMemoryCopy.exportYes}',
        );
      }
      final actionMarker = ActionItemFilter.exportMarkerForEntry(
        entry.id,
        actionItems,
      );
      if (actionMarker != null) buffer.writeln('- $actionMarker');
      final entryFacts = FactLedgerFilter.forEntry(entry.id, facts);
      if (entryFacts.isNotEmpty) {
        buffer.writeln();
        FactLedgerExport.writeEntryFacts(buffer, entryFacts);
      }
      if (entry.entryAboutness != 'about_me') {
        buffer.writeln(
          '- Entry type: ${EntryAboutness.fromId(entry.entryAboutness).label}',
        );
      }
      buffer.writeln(
        '- Surfacing: ${MemorySurfacingMode.fromEntry(entry).label}',
      );
      buffer
        ..writeln('- Memory status: ${status.label}')
        ..writeln()
        ..writeln(entry.transcript.trim());
      if (entry.reflection.concreteObservation.trim().isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('### ${CuratedMemoryCopy.generatedSummaryLabel}')
          ..writeln(entry.reflection.concreteObservation.trim());
      }
    }

    return buffer.toString();
  }
}
