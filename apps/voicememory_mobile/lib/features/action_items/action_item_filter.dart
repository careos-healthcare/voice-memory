import 'archive_action_item.dart';

/// Local search and filter helpers for action items.
///
/// Query text stays in widget state only — never logged or persisted.
abstract class ActionItemFilter {
  ActionItemFilter._();

  /// Active (non-dismissed) action items matching [keyword] in title/note.
  static List<ArchiveActionItem> search(
    List<ArchiveActionItem> items,
    String keyword,
  ) {
    final term = keyword.trim().toLowerCase();
    final active = items.where((item) => !item.isDismissed).toList();
    if (term.isEmpty) return active;
    return active
        .where(
          (item) =>
              item.title.toLowerCase().contains(term) ||
              item.note.toLowerCase().contains(term),
        )
        .toList();
  }

  /// Entry ids with at least one non-dismissed linked action item.
  static Set<String> entryIdsWithActionItems(List<ArchiveActionItem> items) => {
    for (final item in items)
      if (!item.isDismissed) item.sourceEntryId,
  };

  /// Export marker for one entry — open takes precedence over done.
  static String? exportMarkerForEntry(
    String entryId,
    List<ArchiveActionItem> items,
  ) {
    var hasDone = false;
    for (final item in items) {
      if (item.sourceEntryId != entryId || item.isDismissed) continue;
      if (item.isOpen) return ActionItemsCopy.exportMarkerOpen;
      if (item.isDone) hasDone = true;
    }
    return hasDone ? ActionItemsCopy.exportMarkerDone : null;
  }

  /// Open action items only — for dedicated action-item export.
  static List<ArchiveActionItem> exportableItems(
    List<ArchiveActionItem> items, {
    Iterable<String>? selectedIds,
  }) {
    final selected = selectedIds?.toSet();
    return items
        .where(
          (item) =>
              !item.isDismissed &&
              (selected == null || selected.contains(item.id)),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
