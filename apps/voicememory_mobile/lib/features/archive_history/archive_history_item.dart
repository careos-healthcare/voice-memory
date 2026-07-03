/// Status chip for one saved moment in archive history.
enum ArchiveHistoryStatus {
  usedAsEvidence,
  savedOnly,
  transcriptPending,
  needsYourWords,
  ignoredForPatterns,
}

/// One row in the archive history sheet.
class ArchiveHistoryItem {
  const ArchiveHistoryItem({
    required this.entryId,
    required this.dateTimeLabel,
    required this.previewText,
    required this.status,
    this.evidenceNote,
    this.showAddWordsCta = false,
  });

  final String entryId;
  final String dateTimeLabel;
  final String previewText;
  final ArchiveHistoryStatus status;
  final String? evidenceNote;
  final bool showAddWordsCta;
}

/// Content for the archive history bottom sheet.
class ArchiveHistoryContent {
  const ArchiveHistoryContent({
    required this.items,
    required this.isEmpty,
  });

  final List<ArchiveHistoryItem> items;
  final bool isEmpty;
}
