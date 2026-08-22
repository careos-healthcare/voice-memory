/// A user-created thread for grouping related entries.
///
/// Thread names are user-private text — never logged to analytics.
class ArchiveThread {
  const ArchiveThread({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.entryIds = const [],
  });

  factory ArchiveThread.fromJson(Map<String, dynamic> json) {
    final idsRaw = json['entryIds'];
    final entryIds = idsRaw is List
        ? idsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return ArchiveThread(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      entryIds: entryIds,
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> entryIds;

  bool contains(String entryId) => entryIds.contains(entryId);

  ArchiveThread copyWith({
    String? name,
    DateTime? updatedAt,
    List<String>? entryIds,
  }) => ArchiveThread(
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
}