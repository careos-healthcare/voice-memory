/// User actions on post-save possible signals — local only.
enum PostSaveSignalAction {
  accepted,
  rejected,
  deeperOpened,
  nextEvidenceChosen,
  anotherAngleShown,
  abChoiceA,
  abChoiceB,
  abChoiceNeither,
}

extension PostSaveSignalActionIds on PostSaveSignalAction {
  String get id => name;
}

PostSaveSignalAction? postSaveSignalActionFromId(String? id) {
  for (final a in PostSaveSignalAction.values) {
    if (a.name == id) return a;
  }
  return null;
}

class PostSaveSignalFeedback {
  const PostSaveSignalFeedback({
    required this.id,
    required this.signalId,
    required this.signalTitle,
    required this.action,
    required this.createdAt,
    this.entryId,
    this.categoryId,
  });

  final String id;
  final String signalId;
  final String signalTitle;
  final PostSaveSignalAction action;
  final DateTime createdAt;
  final String? entryId;
  final String? categoryId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'signalId': signalId,
    'signalTitle': signalTitle,
    'action': action.id,
    'createdAt': createdAt.toIso8601String(),
    if (entryId != null) 'entryId': entryId,
    if (categoryId != null) 'categoryId': categoryId,
  };

  static PostSaveSignalFeedback? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final signalId = map['signalId'] as String?;
    final signalTitle = map['signalTitle'] as String?;
    final action = postSaveSignalActionFromId(map['action'] as String?);
    final createdRaw = map['createdAt'] as String?;
    if (id == null ||
        signalId == null ||
        signalTitle == null ||
        action == null ||
        createdRaw == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;
    return PostSaveSignalFeedback(
      id: id,
      signalId: signalId,
      signalTitle: signalTitle,
      action: action,
      createdAt: createdAt,
      entryId: map['entryId'] as String?,
      categoryId: map['categoryId'] as String?,
    );
  }
}
