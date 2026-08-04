/// Collections — lightweight, user-created groups of entries.
///
/// Organization only: membership never touches memory scope, memory
/// authority, evidence status, or the entries themselves. Deleting a
/// collection deletes the group, not the entries. Collection names are
/// user-private text and never enter analytics or logs.
class ArchiveCollection {
  const ArchiveCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.entryIds = const [],
  });

  final String id;

  /// User-private text. Shown in the UI only — never logged.
  final String name;

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> entryIds;

  bool contains(String entryId) => entryIds.contains(entryId);

  ArchiveCollection copyWith({
    String? name,
    DateTime? updatedAt,
    List<String>? entryIds,
  }) => ArchiveCollection(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    entryIds: entryIds ?? this.entryIds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'entryIds': entryIds,
  };

  factory ArchiveCollection.fromJson(Map<String, dynamic> json) {
    return ArchiveCollection(
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
    );
  }
}

/// All consumer copy for Collections — compile-time constants so tests
/// can sweep them and no private content can leak in.
abstract class ArchiveCollectionsCopy {
  ArchiveCollectionsCopy._();

  static const String settingsTitle = 'Collections';
  static const String settingsSubtitle = 'Group entries you want to revisit.';

  static const String screenTitle = 'Collections';
  static const String intro = 'Group entries you want to revisit together.';
  static const String emptyTitle = 'No collections yet';
  static const String emptyHelper =
      'Create a collection for decisions, ideas, or anything you want to '
      'keep together.';

  static const String createCollection = 'Create collection';
  static const String newCollection = 'New collection';
  static const String nameLabel = 'Collection name';
  static const String addToCollection = 'Add to collection';
  static const String removeFromCollection = 'Remove from collection';
  static const String renameCollection = 'Rename collection';
  static const String deleteCollection = 'Delete collection';

  static const String deleteConfirmTitle = 'Delete this collection?';
  static const String deleteConfirmBody =
      'Entries inside it will stay in your archive.';

  static const List<String> namePlaceholders = [
    'Work decisions',
    'Business ideas',
    'Things to revisit',
  ];
}
