/// Focused painful loop ArchiveMe optimizes around.
class LoopMode {
  const LoopMode({
    required this.id,
    required this.title,
    required this.shortPromise,
    required this.active,
    required this.startedAt,
    required this.updatedAt,
    required this.activePrompt, required this.interpretationBiasTags, required this.confirmSignals, required this.contradictionSignals, required this.reminderCopy, required this.reviewTitle, this.targetRecordingCount = 3,
    this.completedRecordingCount = 0,
    this.firstPromptUsed = false,
    this.readAccepted = false,
    this.unsupportedRecording = false,
    this.completed = false,
  });

  final String id;
  final String title;
  final String shortPromise;
  final bool active;
  final DateTime startedAt;
  final DateTime updatedAt;
  final int targetRecordingCount;
  final int completedRecordingCount;
  final String activePrompt;
  final List<String> interpretationBiasTags;
  final List<String> confirmSignals;
  final List<String> contradictionSignals;
  final String reminderCopy;
  final String reviewTitle;
  final bool firstPromptUsed;
  final bool readAccepted;
  final bool unsupportedRecording;
  final bool completed;

  bool get isCapacityYes => id == LoopModeIds.capacityYes;

  bool get isProveEnough => id == LoopModeIds.proveEnough;

  bool get isFullyImplementedLoop => isCapacityYes || isProveEnough;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'shortPromise': shortPromise,
    'active': active,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'targetRecordingCount': targetRecordingCount,
    'completedRecordingCount': completedRecordingCount,
    'activePrompt': activePrompt,
    'interpretationBiasTags': interpretationBiasTags,
    'confirmSignals': confirmSignals,
    'contradictionSignals': contradictionSignals,
    'reminderCopy': reminderCopy,
    'reviewTitle': reviewTitle,
    'firstPromptUsed': firstPromptUsed,
    'readAccepted': readAccepted,
    'unsupportedRecording': unsupportedRecording,
    'completed': completed,
  };

  static LoopMode? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null) return null;
    final started = DateTime.tryParse(map['startedAt'] as String? ?? '');
    final updated = DateTime.tryParse(map['updatedAt'] as String? ?? '');
    if (started == null || updated == null) return null;
    List<String> strings(String key) {
      final raw = map[key];
      if (raw is! List) return const [];
      return raw.map((e) => e.toString()).toList();
    }

    return LoopMode(
      id: id,
      title: map['title'] as String? ?? id,
      shortPromise: map['shortPromise'] as String? ?? '',
      active: map['active'] == true,
      startedAt: started,
      updatedAt: updated,
      targetRecordingCount: (map['targetRecordingCount'] as num?)?.toInt() ?? 3,
      completedRecordingCount:
          (map['completedRecordingCount'] as num?)?.toInt() ?? 0,
      activePrompt: map['activePrompt'] as String? ?? '',
      interpretationBiasTags: strings('interpretationBiasTags'),
      confirmSignals: strings('confirmSignals'),
      contradictionSignals: strings('contradictionSignals'),
      reminderCopy: map['reminderCopy'] as String? ?? '',
      reviewTitle: map['reviewTitle'] as String? ?? '',
      firstPromptUsed: map['firstPromptUsed'] == true,
      readAccepted: map['readAccepted'] == true,
      unsupportedRecording: map['unsupportedRecording'] == true,
      completed: map['completed'] == true,
    );
  }

  LoopMode copyWith({
    String? id,
    String? title,
    String? shortPromise,
    bool? active,
    DateTime? startedAt,
    DateTime? updatedAt,
    int? targetRecordingCount,
    int? completedRecordingCount,
    String? activePrompt,
    List<String>? interpretationBiasTags,
    List<String>? confirmSignals,
    List<String>? contradictionSignals,
    String? reminderCopy,
    String? reviewTitle,
    bool? firstPromptUsed,
    bool? readAccepted,
    bool? unsupportedRecording,
    bool? completed,
  }) {
    return LoopMode(
      id: id ?? this.id,
      title: title ?? this.title,
      shortPromise: shortPromise ?? this.shortPromise,
      active: active ?? this.active,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      targetRecordingCount: targetRecordingCount ?? this.targetRecordingCount,
      completedRecordingCount:
          completedRecordingCount ?? this.completedRecordingCount,
      activePrompt: activePrompt ?? this.activePrompt,
      interpretationBiasTags:
          interpretationBiasTags ?? this.interpretationBiasTags,
      confirmSignals: confirmSignals ?? this.confirmSignals,
      contradictionSignals: contradictionSignals ?? this.contradictionSignals,
      reminderCopy: reminderCopy ?? this.reminderCopy,
      reviewTitle: reviewTitle ?? this.reviewTitle,
      firstPromptUsed: firstPromptUsed ?? this.firstPromptUsed,
      readAccepted: readAccepted ?? this.readAccepted,
      unsupportedRecording: unsupportedRecording ?? this.unsupportedRecording,
      completed: completed ?? this.completed,
    );
  }
}

/// Known loop ids — capacity_yes and prove_enough are fully implemented.
abstract class LoopModeIds {
  LoopModeIds._();

  static const capacityYes = 'capacity_yes';
  static const proveEnough = 'prove_enough';
  static const relationshipReplay = 'relationship_replay';
  static const avoidConversation = 'avoid_conversation';
  static const repeatingHabit = 'repeating_habit';
  static const notSure = 'not_sure';
}

/// Progress status for Loop Mode UI.
enum LoopProgressStatus {
  lookingForFirstEvidence,
  earlySignal,
  gettingClearer,
  readyToReview,
}

extension LoopProgressStatusIds on LoopProgressStatus {
  String get id => name;
}