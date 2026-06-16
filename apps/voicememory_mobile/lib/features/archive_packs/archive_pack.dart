/// Archive Packs — bounded memory areas for separate projects/life
/// contexts. Pack names and instructions are user-private text and
/// never enter analytics or logs.
class ArchivePack {
  const ArchivePack({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.entryIds = const [],
    this.instructions = '',
    this.memoryMode,
    this.allowCrossPackConnections = false,
  });

  final String id;

  /// User-private text. Shown in the UI only — never logged.
  final String name;

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> entryIds;

  /// Style notes / project rules — background context only, not evidence.
  final String instructions;

  /// Optional pack-level memory mode id; null inherits global scope.
  final String? memoryMode;

  /// When true, entries in this pack may connect across pack boundaries.
  final bool allowCrossPackConnections;

  bool contains(String entryId) => entryIds.contains(entryId);

  ArchivePack copyWith({
    String? name,
    DateTime? updatedAt,
    List<String>? entryIds,
    String? instructions,
    String? memoryMode,
    bool? allowCrossPackConnections,
    bool clearMemoryMode = false,
  }) => ArchivePack(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    entryIds: entryIds ?? this.entryIds,
    instructions: instructions ?? this.instructions,
    memoryMode: clearMemoryMode ? null : (memoryMode ?? this.memoryMode),
    allowCrossPackConnections:
        allowCrossPackConnections ?? this.allowCrossPackConnections,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'entryIds': entryIds,
    if (instructions.isNotEmpty) 'instructions': instructions,
    if (memoryMode != null) 'memoryMode': memoryMode,
    if (allowCrossPackConnections) 'allowCrossPackConnections': true,
  };

  factory ArchivePack.fromJson(Map<String, dynamic> json) {
    return ArchivePack(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entryIds:
          (json['entryIds'] as List?)?.whereType<String>().toList() ?? const [],
      instructions: json['instructions'] as String? ?? '',
      memoryMode: json['memoryMode'] as String?,
      allowCrossPackConnections: json['allowCrossPackConnections'] == true,
    );
  }
}

/// All consumer copy for Archive Packs — compile-time constants.
abstract class ArchivePacksCopy {
  ArchivePacksCopy._();

  static const String settingsTitle = 'Archive Packs';
  static const String settingsSubtitle =
      'Separate projects so memory stays scoped.';

  static const String screenTitle = 'Archive Packs';
  static const String intro =
      'Separate major projects or life areas. Memory stays inside a pack '
      'unless you allow otherwise.';
  static const String emptyTitle = 'No packs yet';
  static const String emptyHelper =
      'Create a pack for work, a novel, business ideas, or anything you '
      'want kept apart.';

  static const String createPack = 'Create pack';
  static const String newPack = 'New pack';
  static const String packName = 'Pack name';
  static const String addToPack = 'Add to pack';
  static const String moveToPack = 'Move to pack';
  static const String saveToPack = 'Save to pack';
  static const String noPack = 'No pack';
  static const String packInstructions = 'Pack instructions';
  static const String packInstructionsHelper =
      'Use this for style notes, project rules, or details you want kept '
      'with this pack.';
  static const String memoryBoundaryLine =
      'Memory stays inside this pack unless you allow otherwise.';
  static const String entriesInPack = 'Entries in this pack';
  static const String searchThisPack = 'Search this pack';
  static const String pinnedInPack = 'Pinned in this pack';
  static const String exportPack = 'Export pack';
  static const String renamePack = 'Rename pack';
  static const String deletePack = 'Delete pack';
  static const String deletePackConfirm =
      'Delete this pack? Entries stay in your archive.';

  static const String crossPackTitle = 'Connect across packs?';
  static const String crossPackBody =
      'This may relate to another pack. Connect it?';
  static const String crossPackConnect = 'Connect';
  static const String crossPackKeepSeparate = 'Keep separate';

  static const List<String> exampleNames = [
    'Work',
    'Novel',
    'Business ideas',
    'Personal',
  ];

  static const List<String> all = [
    settingsTitle,
    settingsSubtitle,
    screenTitle,
    intro,
    emptyTitle,
    emptyHelper,
    createPack,
    newPack,
    packName,
    addToPack,
    moveToPack,
    saveToPack,
    noPack,
    packInstructions,
    packInstructionsHelper,
    memoryBoundaryLine,
    entriesInPack,
    searchThisPack,
    pinnedInPack,
    exportPack,
    renamePack,
    deletePack,
    deletePackConfirm,
    crossPackTitle,
    crossPackBody,
    crossPackConnect,
    crossPackKeepSeparate,
  ];
}
