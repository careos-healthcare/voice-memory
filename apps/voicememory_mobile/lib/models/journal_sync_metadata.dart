class JournalSyncMetadata {
  const JournalSyncMetadata({
    required this.updatedAt,
    required this.sourceDeviceId,
    this.vectorClock = const <String, int>{},
    this.serverUpdatedAt,
  });

  final DateTime updatedAt;
  final String sourceDeviceId;
  final Map<String, int> vectorClock;
  final DateTime? serverUpdatedAt;

  factory JournalSyncMetadata.fromJson(
    Map<String, dynamic> json, {
    DateTime? serverUpdatedAt,
  }) {
    final rawClock = json['vectorClock'];
    final clock = <String, int>{};
    if (rawClock is Map) {
      for (final entry in rawClock.entries) {
        final value = entry.value;
        if (value is num && value >= 0) {
          clock[entry.key.toString()] = value.toInt();
        }
      }
    }
    return JournalSyncMetadata(
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
          serverUpdatedAt?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sourceDeviceId: json['sourceDeviceId']?.toString().trim() ?? '',
      vectorClock: Map<String, int>.unmodifiable(clock),
      serverUpdatedAt: serverUpdatedAt?.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'sourceDeviceId': sourceDeviceId,
    if (vectorClock.isNotEmpty) 'vectorClock': vectorClock,
  };

  JournalSyncMetadata copyWith({
    DateTime? updatedAt,
    String? sourceDeviceId,
    Map<String, int>? vectorClock,
    DateTime? serverUpdatedAt,
  }) => JournalSyncMetadata(
    updatedAt: updatedAt ?? this.updatedAt,
    sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
    vectorClock: vectorClock ?? this.vectorClock,
    serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
  );
}

enum VectorClockRelation { equal, dominates, isDominated, concurrent }

VectorClockRelation compareVectorClocks(
  Map<String, int> left,
  Map<String, int> right,
) {
  if (left.isEmpty || right.isEmpty) return VectorClockRelation.concurrent;
  var leftAhead = false;
  var rightAhead = false;
  for (final deviceId in <String>{...left.keys, ...right.keys}) {
    final leftValue = left[deviceId] ?? 0;
    final rightValue = right[deviceId] ?? 0;
    if (leftValue > rightValue) leftAhead = true;
    if (rightValue > leftValue) rightAhead = true;
  }
  if (!leftAhead && !rightAhead) return VectorClockRelation.equal;
  if (leftAhead && !rightAhead) return VectorClockRelation.dominates;
  if (rightAhead && !leftAhead) return VectorClockRelation.isDominated;
  return VectorClockRelation.concurrent;
}

Map<String, int> incrementVectorClock(
  Map<String, int> current,
  String deviceId,
) {
  final next = <String, int>{...current};
  next[deviceId] = (next[deviceId] ?? 0) + 1;
  return Map<String, int>.unmodifiable(next);
}
