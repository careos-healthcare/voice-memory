/// Post-save curiosity hook persisted for the voice return loop.
enum CuriosityHookType {
  anchorFollowUp,
  blocker,
  momentum,
  returnWatch,
}

/// A single targeted curiosity prompt tied to one saved moment.
class CuriosityHook {
  const CuriosityHook({
    required this.id,
    required this.entryId,
    required this.createdAt,
    required this.primaryAnchor,
    required this.hookType,
    required this.dynamicPrompt,
    this.sourceEntryId,
    this.isMemoryRecallCheck = false,
    this.isConsumed = false,
  });

  final String id;
  final String entryId;
  final DateTime createdAt;
  final String primaryAnchor;
  final CuriosityHookType hookType;
  final String dynamicPrompt;
  final String? sourceEntryId;
  final bool isMemoryRecallCheck;
  final bool isConsumed;

  CuriosityHook copyWith({
    String? id,
    String? entryId,
    DateTime? createdAt,
    String? primaryAnchor,
    CuriosityHookType? hookType,
    String? dynamicPrompt,
    String? sourceEntryId,
    bool? isMemoryRecallCheck,
    bool? isConsumed,
  }) {
    return CuriosityHook(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      createdAt: createdAt ?? this.createdAt,
      primaryAnchor: primaryAnchor ?? this.primaryAnchor,
      hookType: hookType ?? this.hookType,
      dynamicPrompt: dynamicPrompt ?? this.dynamicPrompt,
      sourceEntryId: sourceEntryId ?? this.sourceEntryId,
      isMemoryRecallCheck: isMemoryRecallCheck ?? this.isMemoryRecallCheck,
      isConsumed: isConsumed ?? this.isConsumed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryId': entryId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'primaryAnchor': primaryAnchor,
        'hookType': hookType.name,
        'dynamicPrompt': dynamicPrompt,
        if (sourceEntryId != null && sourceEntryId!.isNotEmpty)
          'sourceEntryId': sourceEntryId,
        if (isMemoryRecallCheck) 'isMemoryRecallCheck': true,
        'isConsumed': isConsumed,
      };

  static CuriosityHook? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final id = json['id'] as String?;
    final entryId = json['entryId'] as String?;
    final primaryAnchor = json['primaryAnchor'] as String?;
    final dynamicPrompt = json['dynamicPrompt'] as String?;
    if (id == null ||
        id.isEmpty ||
        entryId == null ||
        entryId.isEmpty ||
        primaryAnchor == null ||
        primaryAnchor.trim().isEmpty ||
        dynamicPrompt == null ||
        dynamicPrompt.trim().isEmpty) {
      return null;
    }
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (createdAt == null) return null;
    final hookType = _parseHookType(json['hookType'] as String?);
    if (hookType == null) return null;
    return CuriosityHook(
      id: id,
      entryId: entryId,
      createdAt: createdAt,
      primaryAnchor: primaryAnchor.trim(),
      hookType: hookType,
      dynamicPrompt: dynamicPrompt.trim(),
      sourceEntryId: _parseOptionalId(json['sourceEntryId'] as String?),
      isMemoryRecallCheck: json['isMemoryRecallCheck'] == true,
      isConsumed: json['isConsumed'] == true,
    );
  }

  static String? _parseOptionalId(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static CuriosityHookType? _parseHookType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in CuriosityHookType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CuriosityHook &&
            other.id == id &&
            other.entryId == entryId &&
            other.createdAt == createdAt &&
            other.primaryAnchor == primaryAnchor &&
            other.hookType == hookType &&
            other.dynamicPrompt == dynamicPrompt &&
            other.sourceEntryId == sourceEntryId &&
            other.isMemoryRecallCheck == isMemoryRecallCheck &&
            other.isConsumed == isConsumed;
  }

  @override
  int get hashCode => Object.hash(
        id,
        entryId,
        createdAt,
        primaryAnchor,
        hookType,
        dynamicPrompt,
        sourceEntryId,
        isMemoryRecallCheck,
        isConsumed,
      );
}
