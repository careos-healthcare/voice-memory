/// User-confirmed action items — concrete things to remember or follow up
/// on. Title and note are user-private text and never enter analytics.
class ArchiveActionItem {
  const ArchiveActionItem({
    required this.id,
    required this.sourceEntryId,
    required this.title,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.dueAt,
    this.isReminderEnabled,
    this.archivePackId,
    this.archiveThreadId,
    this.collectionIds = const [],
  });

  final String id;
  final String sourceEntryId;

  /// User-private text. Shown in the UI only — never logged.
  final String title;

  /// User-private text. Shown in the UI only — never logged.
  final String note;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final DateTime? dueAt;
  final bool? isReminderEnabled;
  final String? archivePackId;
  final String? archiveThreadId;
  final List<String> collectionIds;

  bool get isOpen => status == ActionItemStatus.open;
  bool get isDone => status == ActionItemStatus.done;
  bool get isDismissed => status == ActionItemStatus.dismissed;

  ArchiveActionItem copyWith({
    String? title,
    String? note,
    DateTime? updatedAt,
    String? status,
    DateTime? Function()? dueAt,
    bool? isReminderEnabled,
    String? archivePackId,
    String? archiveThreadId,
    List<String>? collectionIds,
    bool clearDueAt = false,
  }) => ArchiveActionItem(
    id: id,
    sourceEntryId: sourceEntryId,
    title: title ?? this.title,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    dueAt: clearDueAt ? null : (dueAt != null ? dueAt() : this.dueAt),
    isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
    archivePackId: archivePackId ?? this.archivePackId,
    archiveThreadId: archiveThreadId ?? this.archiveThreadId,
    collectionIds: collectionIds ?? this.collectionIds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceEntryId': sourceEntryId,
    'title': title,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status,
    if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
    if (isReminderEnabled == true) 'isReminderEnabled': true,
    if (archivePackId != null) 'archivePackId': archivePackId,
    if (archiveThreadId != null) 'archiveThreadId': archiveThreadId,
    if (collectionIds.isNotEmpty) 'collectionIds': collectionIds,
  };

  factory ArchiveActionItem.fromJson(Map<String, dynamic> json) {
    return ArchiveActionItem(
      id: json['id'] as String? ?? '',
      sourceEntryId: json['sourceEntryId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: json['status'] as String? ?? ActionItemStatus.open,
      dueAt: json['dueAt'] is String
          ? DateTime.tryParse(json['dueAt'] as String)
          : null,
      isReminderEnabled: json['isReminderEnabled'] == true ? true : null,
      archivePackId: json['archivePackId'] as String?,
      archiveThreadId: json['archiveThreadId'] as String?,
      collectionIds:
          (json['collectionIds'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }
}

/// Stable status ids for action items.
abstract class ActionItemStatus {
  ActionItemStatus._();

  static const String open = 'open';
  static const String done = 'done';
  static const String dismissed = 'dismissed';

  static const Set<String> all = {open, done, dismissed};
}

/// All consumer copy for Action Items — compile-time constants.
abstract class ActionItemsCopy {
  ActionItemsCopy._();

  static const String settingsTitle = 'Action items';
  static const String settingsSubtitle = 'Things you chose to remember.';

  static const String screenTitle = 'Action items';
  static const String emptyTitle = 'No action items yet';
  static const String emptyHelper =
      'Use Remember this on an entry when something needs follow-up.';

  static const String rememberThis = 'Remember this';
  static const String savedReceipt = 'Saved to Action Items';
  static const String alreadyRemembered = 'Already remembered';

  static const String titleLabel = 'Title';
  static const String noteLabel = 'Note';
  static const String save = 'Save';
  static const String edit = 'Edit';
  static const String markDone = 'Mark done';
  static const String dismiss = 'Dismiss';
  static const String exportActionItems = 'Export action items';

  static const String addReminder = 'Add reminder';
  static const String chooseDate = 'Choose date';
  static const String reminderSaved = 'Reminder saved';
  static const String dueDateLabel = 'Due date';

  static const String exportMarkerOpen = 'Action item: open';
  static const String exportMarkerDone = 'Action item: done';

  static const String actionItemsFilterLabel = 'Action items';

  static const List<String> all = [
    settingsTitle,
    settingsSubtitle,
    screenTitle,
    emptyTitle,
    emptyHelper,
    rememberThis,
    savedReceipt,
    alreadyRemembered,
    titleLabel,
    noteLabel,
    save,
    edit,
    markDone,
    dismiss,
    exportActionItems,
    addReminder,
    chooseDate,
    reminderSaved,
    dueDateLabel,
    exportMarkerOpen,
    exportMarkerDone,
    actionItemsFilterLabel,
  ];
}
