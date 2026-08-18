import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// UI-facing display state for a journal entry — decoupled from persistence.
class JournalDisplayPresentation {
  const JournalDisplayPresentation({required this.metadata});

  /// Maps persisted [JournalEntry] metadata to presentation display state.
  factory JournalDisplayPresentation.fromEntry(JournalEntry entry) =>
      JournalDisplayPresentation(metadata: entry.display);

  /// Maps raw persisted metadata to presentation display state.
  factory JournalDisplayPresentation.fromMetadata(
    JournalDisplayMetadata metadata,
  ) => JournalDisplayPresentation(metadata: metadata);

  final JournalDisplayMetadata metadata;

  bool get treatAsNew => metadata.treatAsNew;
  bool get connectionApproved => metadata.connectionApproved;
  bool get keepExactDetails => metadata.keepExactDetails;
  bool get keepSeparate => metadata.keepSeparate;
  String? get archiveThreadId => metadata.archiveThreadId;
  String? get archivePackId => metadata.archivePackId;
  bool get isPinned => metadata.isPinned;
  DateTime? get pinnedAt => metadata.pinnedAt;
  bool get isArchived => metadata.isArchived;
  DateTime? get archivedAt => metadata.archivedAt;
  String get entryAboutness => metadata.entryAboutness;
  String get memorySurfacing => metadata.memorySurfacing;
  bool get preserveOriginal => metadata.preserveOriginal;
  String? get captureContextTag => metadata.captureContextTag;
  String? get captureSource => metadata.captureSource;

  /// Whether the feed should show a pin indicator for this entry.
  bool get showPinBadge => isPinned;

  /// Whether memory resurfacing is reduced for this entry.
  bool get isReducedMemorySurfacing => memorySurfacing == 'reduced';

  /// Whether the entry is scoped to someone other than the author.
  bool get isAboutSomeoneElse => entryAboutness == 'about_someone_else';

  /// Human-readable label for [entryAboutness].
  String get aboutnessLabel => switch (entryAboutness) {
    'about_someone_else' => 'About someone else',
    'about_us' => 'About us',
    _ => 'About me',
  };

  /// Human-readable label for [memorySurfacing].
  String get memorySurfacingLabel => switch (memorySurfacing) {
    'reduced' => 'Reduced resurfacing',
    'hidden' => 'Hidden from resurfacing',
    _ => 'Normal resurfacing',
  };
}
