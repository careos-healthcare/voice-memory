/// User-created project details — discrete facts, not generated summaries.
///
/// Facts are created only when the user taps Save detail and confirms in
/// the editor. Nothing here auto-extracts from entry text or reflections.
class ArchiveFact {
  const ArchiveFact({
    required this.id,
    required this.sourceEntryId,
    required this.label,
    required this.value,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.factType,
    this.archivePackId,
    this.archiveThreadId,
    this.collectionIds = const [],
    this.isPinned = false,
    this.preserveOriginal = true,
  });

  factory ArchiveFact.fromJson(Map<String, dynamic> json) {
    return ArchiveFact(
      id: json['id'] as String? ?? '',
      sourceEntryId: json['sourceEntryId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      factType: json['factType'] as String? ?? FactType.projectDetail.id,
      archivePackId: json['archivePackId'] as String?,
      archiveThreadId: json['archiveThreadId'] as String?,
      collectionIds:
          (json['collectionIds'] as List?)?.whereType<String>().toList() ??
          const [],
      isPinned: json['isPinned'] == true,
      preserveOriginal: json['preserveOriginal'] != false,
    );
  }

  final String id;
  final String sourceEntryId;
  final String label;
  final String value;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String factType;
  final String? archivePackId;
  final String? archiveThreadId;
  final List<String> collectionIds;
  final bool isPinned;
  final bool preserveOriginal;

  ArchiveFact copyWith({
    String? label,
    String? value,
    String? note,
    DateTime? updatedAt,
    String? factType,
    bool? isPinned,
  }) => ArchiveFact(
    id: id,
    sourceEntryId: sourceEntryId,
    label: label ?? this.label,
    value: value ?? this.value,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    factType: factType ?? this.factType,
    archivePackId: archivePackId,
    archiveThreadId: archiveThreadId,
    collectionIds: collectionIds,
    isPinned: isPinned ?? this.isPinned,
    preserveOriginal: preserveOriginal,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceEntryId': sourceEntryId,
    'label': label,
    'value': value,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'factType': factType,
    if (archivePackId != null) 'archivePackId': archivePackId,
    if (archiveThreadId != null) 'archiveThreadId': archiveThreadId,
    if (collectionIds.isNotEmpty) 'collectionIds': collectionIds,
    if (isPinned) 'isPinned': true,
    if (preserveOriginal) 'preserveOriginal': true,
  };
}

/// Stable fact-type ids for analytics — never user text.
enum FactType {
  projectDetail('project_detail'),
  contact('contact'),
  deadline('deadline'),
  link('link'),
  credentialReference('credential_reference'),
  decision('decision'),
  checklistItem('checklist_item'),
  evidenceCitation('evidence_citation'),
  other('other');

  const FactType(this.id);

  final String id;

  String get label => switch (this) {
    FactType.projectDetail => 'Project detail',
    FactType.contact => 'Contact',
    FactType.deadline => 'Deadline',
    FactType.link => 'Link',
    FactType.credentialReference => 'Credential reference',
    FactType.decision => 'Decision',
    FactType.checklistItem => 'Checklist item',
    FactType.evidenceCitation => 'Supporting words',
    FactType.other => 'Other',
  };

  static FactType fromId(String? id) {
    for (final type in FactType.values) {
      if (type.id == id) return type;
    }
    return FactType.other;
  }

  static const Set<String> analyticsIds = {
    'project_detail',
    'contact',
    'deadline',
    'link',
    'credential_reference',
    'decision',
    'checklist_item',
    'evidence_citation',
    'other',
  };
}

/// All consumer copy for the fact ledger — compile-time constants.
abstract class FactLedgerCopy {
  FactLedgerCopy._();

  static const String settingsTitle = 'Details';
  static const String settingsSubtitle = 'Specific things you chose to keep.';
  static const String screenTitle = 'Details';
  static const String emptyTitle = 'No saved details yet';
  static const String emptyHelper =
      'Use Save detail on an entry when exact information matters.';

  static const String saveDetail = 'Add note';
  static const String savedReceipt = 'Saved to Details';
  static const String alreadySaved = 'Already saved as detail';

  static const String labelField = 'Label';
  static const String valueField = 'Value';
  static const String noteField = 'Note';
  static const String typeField = 'Type';
  static const String save = 'Save';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String openEntry = 'Open entry';
  static const String pin = 'Pin';
  static const String unpin = 'Unpin';
  static const String exportDetails = 'Export details';

  static const String credentialHelper =
      'Store a reference, not the secret itself.';

  static const String searchFilterLabel = 'Saved details';
  static const String searchChipLabel = 'Saved detail';
  static const String exportSavedDetailPrefix = 'Saved detail';

  static const String citationLabel = 'Supporting words';

  static const List<String> all = [
    settingsTitle,
    settingsSubtitle,
    screenTitle,
    emptyTitle,
    emptyHelper,
    saveDetail,
    savedReceipt,
    alreadySaved,
    labelField,
    valueField,
    noteField,
    typeField,
    save,
    edit,
    delete,
    openEntry,
    pin,
    unpin,
    exportDetails,
    credentialHelper,
    searchFilterLabel,
    searchChipLabel,
    exportSavedDetailPrefix,
    'Project detail',
    'Contact',
    'Deadline',
    'Link',
    'Credential reference',
    'Decision',
    'Checklist item',
    'Other',
  ];
}