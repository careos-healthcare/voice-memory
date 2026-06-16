/// Which prove_enough next-evidence mission was selected.
enum NextEvidenceMissionKind {
  keepGoingAfterEnough,
  stoppingFeelsBehind,
  pressureNotChoice,
  restPossibleOrUnsafe;

  String get id => name;
}

/// One precise next recording mission for the prove_enough loop.
class NextEvidenceMissionModel {
  const NextEvidenceMissionModel({
    required this.mission,
    required this.kind,
    this.sourceEntryId,
    this.updatedAt,
  });

  final String mission;
  final NextEvidenceMissionKind kind;
  final String? sourceEntryId;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'mission': mission,
    'kind': kind.id,
    if (sourceEntryId != null) 'sourceEntryId': sourceEntryId,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  static NextEvidenceMissionModel? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final mission = map['mission'] as String?;
    final kindRaw = map['kind'] as String?;
    if (mission == null || mission.trim().isEmpty || kindRaw == null) {
      return null;
    }
    final kind = NextEvidenceMissionKind.values.firstWhere(
      (k) => k.id == kindRaw,
      orElse: () => NextEvidenceMissionKind.stoppingFeelsBehind,
    );
    return NextEvidenceMissionModel(
      mission: mission.trim(),
      kind: kind,
      sourceEntryId: map['sourceEntryId'] as String?,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
    );
  }
}
