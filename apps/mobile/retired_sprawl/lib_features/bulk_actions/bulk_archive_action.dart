/// Select + Export + Bulk Actions — action ids and consumer copy.
///
/// Users select specific entries and act on only what they chose.
/// Destructive actions confirm first; analytics carries fixed action
/// ids and coarse selection buckets only — never entry text, exported
/// text, or collection names.
enum BulkArchiveAction {
  exportSelected,
  addToCollection,
  pinSelected,
  unpinSelected,
  archiveSelected,
  deleteSelected,
  treatAsNew,
  keepExactDetails;

  /// Stable analytics-safe id.
  String get id => switch (this) {
    BulkArchiveAction.exportSelected => 'export_selected',
    BulkArchiveAction.addToCollection => 'add_to_collection',
    BulkArchiveAction.pinSelected => 'pin_selected',
    BulkArchiveAction.unpinSelected => 'unpin_selected',
    BulkArchiveAction.archiveSelected => 'archive_selected',
    BulkArchiveAction.deleteSelected => 'delete_selected',
    BulkArchiveAction.treatAsNew => 'treat_as_new',
    BulkArchiveAction.keepExactDetails => 'keep_exact_details',
  };

  String get label => switch (this) {
    BulkArchiveAction.exportSelected => BulkActionsCopy.exportSelected,
    BulkArchiveAction.addToCollection => BulkActionsCopy.addToCollection,
    BulkArchiveAction.pinSelected => BulkActionsCopy.pinSelected,
    BulkArchiveAction.unpinSelected => BulkActionsCopy.unpinSelected,
    BulkArchiveAction.archiveSelected => BulkActionsCopy.archiveSelected,
    BulkArchiveAction.deleteSelected => BulkActionsCopy.deleteSelected,
    BulkArchiveAction.treatAsNew => BulkActionsCopy.treatAsNew,
    BulkArchiveAction.keepExactDetails => BulkActionsCopy.keepExactDetails,
  };
}

/// All consumer copy for select mode and bulk actions — compile-time
/// constants so tests can sweep them and no private content can leak in.
abstract class BulkActionsCopy {
  BulkActionsCopy._();

  static const String select = 'Select';
  static const String cancel = 'Cancel';
  static const String selectAll = 'Select all';
  static const String clearSelection = 'Clear selection';

  static String selectedCount(int count) =>
      count == 1 ? '1 selected' : '$count selected';

  static const String exportSelected = 'Export selected';
  static const String addToCollection = 'Add to collection';
  static const String pinSelected = 'Pin selected';
  static const String unpinSelected = 'Unpin selected';
  static const String archiveSelected = 'Archive selected';
  static const String deleteSelected = 'Delete selected';
  static const String treatAsNew = 'Treat selected as new';
  static const String keepExactDetails = 'Keep exact details';

  static const String archiveConfirmTitle = 'Archive selected entries?';
  static const String archiveConfirmBody =
      'You can still find them with the Archived filter.';
  static const String archiveConfirmButton = 'Archive selected';

  static const String deleteConfirmTitle = 'Delete selected entries?';
  static const String deleteConfirmBody =
      'This removes them from your archive.';
  static const String deleteConfirmButton = 'Delete entries';

  static const String chooseFormat = 'Choose format';
  static const String exportMarkdown = 'Export Markdown';
  static const String exportPdf = 'Export PDF';
  static const String exportComplete = 'Export complete';

  static const String archivedFilterLabel = 'Archived';
}