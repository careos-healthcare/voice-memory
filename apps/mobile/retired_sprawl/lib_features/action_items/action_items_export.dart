import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/action_items/archive_action_item.dart';

/// Markdown export of user-selected action items.
///
/// The user chose to export, so title/note may appear in the file.
/// Analytics never sees the exported text.
class ActionItemsExport {
  const ActionItemsExport();

  static String fileName(DateTime now) {
    final local = now.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'archiveme-action-items-${local.year}-$month-$day.md';
  }

  String buildMarkdown({
    required List<ArchiveActionItem> items,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final buffer = StringBuffer()
      ..writeln('# ArchiveMe action items')
      ..writeln()
      ..writeln('Export date: ${formatUserFacingDate(clock)}')
      ..writeln('Items: ${items.length}');

    for (final item in items) {
      buffer
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln('## ${item.title.trim()}')
        ..writeln()
        ..writeln('- Status: ${_statusLabel(item.status)}')
        ..writeln('- Created: ${formatUserFacingDate(item.createdAt)}');
      if (item.dueAt != null) {
        buffer.writeln('- Due: ${formatUserFacingDate(item.dueAt!)}');
      }
      if (item.note.trim().isNotEmpty) {
        buffer
          ..writeln()
          ..writeln(item.note.trim());
      }
    }

    return buffer.toString();
  }

  static String _statusLabel(String status) => switch (status) {
    ActionItemStatus.open => 'Open',
    ActionItemStatus.done => 'Done',
    ActionItemStatus.dismissed => 'Dismissed',
    _ => status,
  };
}