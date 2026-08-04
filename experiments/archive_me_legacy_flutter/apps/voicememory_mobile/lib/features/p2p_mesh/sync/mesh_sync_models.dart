import '../../sync/e2ee_sync_models.dart';
import '../../../models/journal_sync_metadata.dart';

const int meshSyncProtocolVersion = 1;

/// Payload-free LWW metadata for one CRDT entity.
///
/// This is safe to use as a differential summary: private entity payloads stay
/// inside [E2EESyncEnvelope], while all fields used by [CrdtOperation.compare]
/// remain available.
class MeshHeadVersion {
  MeshHeadVersion({
    required this.operationId,
    required this.deviceId,
    required Map<String, int> vectorClock,
    required DateTime timestamp,
  }) : vectorClock = Map.unmodifiable(vectorClock),
       timestamp = timestamp.toUtc();

  factory MeshHeadVersion.fromOperation(CrdtOperation operation) =>
      MeshHeadVersion(
        operationId: operation.id,
        deviceId: operation.deviceId,
        vectorClock: operation.vectorClock,
        timestamp: operation.timestamp,
      );

  factory MeshHeadVersion.fromJson(Map<String, dynamic> json) =>
      MeshHeadVersion(
        operationId: '${json['operationId']}',
        deviceId: '${json['deviceId']}',
        vectorClock: _clock(json['vectorClock']),
        timestamp:
            DateTime.tryParse('${json['timestamp']}') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  final String operationId;
  final String deviceId;
  final Map<String, int> vectorClock;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'deviceId': deviceId,
    'vectorClock': vectorClock,
    'timestamp': timestamp.toIso8601String(),
  };

  int compareOperation(CrdtOperation operation) {
    final relation = compareVectorClocks(operation.vectorClock, vectorClock);
    switch (relation) {
      case VectorClockRelation.dominates:
        return 1;
      case VectorClockRelation.isDominated:
        return -1;
      case VectorClockRelation.equal:
      case VectorClockRelation.concurrent:
        final time = operation.timestamp.compareTo(timestamp);
        if (time != 0) return time;
        final device = operation.deviceId.compareTo(deviceId);
        if (device != 0) return device;
        return operation.id.compareTo(operationId);
    }
  }
}

class MeshHeadSummary {
  MeshHeadSummary({
    required this.deviceId,
    required this.keyEpoch,
    required Map<String, MeshHeadVersion> heads,
  }) : heads = Map.unmodifiable(heads);

  factory MeshHeadSummary.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt();
    if (version != meshSyncProtocolVersion) {
      throw FormatException('Unsupported mesh sync version: $version');
    }
    final rawHeads = json['heads'];
    if (rawHeads is! Map) {
      throw const FormatException('Mesh head summary is missing heads.');
    }
    return MeshHeadSummary(
      deviceId: '${json['deviceId']}',
      keyEpoch: (json['keyEpoch'] as num?)?.toInt() ?? 0,
      heads: {
        for (final entry in rawHeads.entries)
          '${entry.key}': MeshHeadVersion.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
    );
  }

  final String deviceId;
  final int keyEpoch;
  final Map<String, MeshHeadVersion> heads;

  Map<String, dynamic> toJson() => {
    'version': meshSyncProtocolVersion,
    'deviceId': deviceId,
    'keyEpoch': keyEpoch,
    'heads': {
      for (final entry in heads.entries) entry.key: entry.value.toJson(),
    },
  };
}

class MeshExportPage {
  MeshExportPage({
    required List<E2EESyncEnvelope> envelopes,
    required this.nextCursor,
    required this.isComplete,
  }) : envelopes = List.unmodifiable(envelopes);

  factory MeshExportPage.fromJson(Map<String, dynamic> json) {
    final raw = json['envelopes'];
    if (raw is! List) {
      throw const FormatException('Mesh export page is missing envelopes.');
    }
    return MeshExportPage(
      envelopes: raw
          .whereType<Map>()
          .map(
            (item) =>
                E2EESyncEnvelope.fromRelayBlob(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      isComplete: json['isComplete'] == true,
    );
  }

  final List<E2EESyncEnvelope> envelopes;
  final String? nextCursor;
  final bool isComplete;

  Map<String, dynamic> toJson() => {
    'version': meshSyncProtocolVersion,
    'envelopes': envelopes.map((item) => item.toRelayBlob()).toList(),
    'nextCursor': nextCursor,
    'isComplete': isComplete,
  };
}

class MeshApplyResult {
  const MeshApplyResult({
    required this.receivedEnvelopeCount,
    required this.appliedWinnerCount,
    required this.duplicateEnvelopeCount,
  });

  final int receivedEnvelopeCount;
  final int appliedWinnerCount;
  final int duplicateEnvelopeCount;
}

Map<String, int> _clock(Object? raw) {
  if (raw is! Map) return const {};
  return Map.unmodifiable({
    for (final entry in raw.entries)
      if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
  });
}
