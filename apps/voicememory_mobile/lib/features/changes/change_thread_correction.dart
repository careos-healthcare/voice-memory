/// What the user did to a thread when ArchiveMe grouped things wrongly.
///
/// Corrections are user data, not derived data. They are stored separately
/// from the projection and replayed over it every time, so re-deriving threads
/// from conclusions can never quietly undo a rename or re-merge a split.
sealed class ChangeThreadCorrection {
  const ChangeThreadCorrection({required this.threadId, required this.at});

  final String threadId;
  final DateTime at;

  Map<String, dynamic> toJson();

  static ChangeThreadCorrection? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final threadId = json['threadId']?.toString() ?? '';
    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (threadId.isEmpty || at == null) return null;
    return switch (json['type']?.toString()) {
      'rename' => RenameChangeThread(
        threadId: threadId,
        label: json['label']?.toString() ?? '',
        at: at.toUtc(),
      ),
      'split' => SplitChangeThread(
        threadId: threadId,
        eventIds: (json['eventIds'] as List? ?? const [])
            .map((item) => item.toString())
            .toSet(),
        newLabel: json['newLabel']?.toString(),
        at: at.toUtc(),
      ),
      'merge' => MergeChangeThreads(
        threadId: threadId,
        intoThreadId: json['intoThreadId']?.toString() ?? '',
        at: at.toUtc(),
      ),
      'suppress' => SuppressChangeThreadFraming(
        threadId: threadId,
        eventId: json['eventId']?.toString(),
        at: at.toUtc(),
      ),
      _ => null,
    };
  }
}

/// The user names the thread. A confirmed label also pins its identity, so
/// later findings join it on a single shared marker.
class RenameChangeThread extends ChangeThreadCorrection {
  const RenameChangeThread({
    required super.threadId,
    required this.label,
    required super.at,
  });

  final String label;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'rename',
    'threadId': threadId,
    'label': label,
    'at': at.toUtc().toIso8601String(),
  };
}

/// The user says some moments do not belong here. They move out together into
/// a thread of their own rather than being deleted.
class SplitChangeThread extends ChangeThreadCorrection {
  SplitChangeThread({
    required super.threadId,
    required Iterable<String> eventIds,
    required super.at,
    this.newLabel,
  }) : eventIds = Set.unmodifiable(eventIds);

  final Set<String> eventIds;
  final String? newLabel;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'split',
    'threadId': threadId,
    'eventIds': eventIds.toList(growable: false)..sort(),
    if (newLabel != null) 'newLabel': newLabel,
    'at': at.toUtc().toIso8601String(),
  };
}

/// The user says two threads are the same thing. Applied only when the two
/// genuinely share subject markers, so a mis-tap cannot fuse unrelated
/// histories into one card.
class MergeChangeThreads extends ChangeThreadCorrection {
  const MergeChangeThreads({
    required super.threadId,
    required this.intoThreadId,
    required super.at,
  });

  final String intoThreadId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'merge',
    'threadId': threadId,
    'intoThreadId': intoThreadId,
    'at': at.toUtc().toIso8601String(),
  };
}

/// The user says this reading is the wrong angle. The thread, or one event in
/// it, stops being shown without any of the saved moments being touched.
class SuppressChangeThreadFraming extends ChangeThreadCorrection {
  const SuppressChangeThreadFraming({
    required super.threadId,
    required super.at,
    this.eventId,
  });

  final String? eventId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'suppress',
    'threadId': threadId,
    if (eventId != null) 'eventId': eventId,
    'at': at.toUtc().toIso8601String(),
  };
}
