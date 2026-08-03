import 'api_transport.dart';

class SyncManifestBlobMetadata {
  const SyncManifestBlobMetadata({
    required this.id,
    required this.type,
    required this.updatedAt,
    required this.byteLength,
  });

  final String id;
  final String type;
  final DateTime updatedAt;
  final int byteLength;

  factory SyncManifestBlobMetadata.fromJson(Map<String, dynamic> json) =>
      SyncManifestBlobMetadata(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        byteLength: (json['byteLength'] as num?)?.toInt() ?? 0,
      );
}

class SyncManifestCollision {
  const SyncManifestCollision({
    required this.recordId,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    this.localVectorClock = const <String, int>{},
    this.remoteVectorClock = const <String, int>{},
  });

  final String recordId;
  final DateTime? localUpdatedAt;
  final DateTime? remoteUpdatedAt;
  final Map<String, int> localVectorClock;
  final Map<String, int> remoteVectorClock;

  factory SyncManifestCollision.fromJson(Map<String, dynamic> json) {
    Map<String, int> clock(Object? raw) {
      if (raw is! Map) return const <String, int>{};
      return Map<String, int>.unmodifiable({
        for (final entry in raw.entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toInt(),
      });
    }

    return SyncManifestCollision(
      recordId:
          json['recordId']?.toString() ??
          json['entryId']?.toString() ??
          json['blobId']?.toString() ??
          json['id']?.toString() ??
          '',
      localUpdatedAt: DateTime.tryParse(
        json['localUpdatedAt']?.toString() ?? '',
      )?.toUtc(),
      remoteUpdatedAt: DateTime.tryParse(
        json['remoteUpdatedAt']?.toString() ?? '',
      )?.toUtc(),
      localVectorClock: clock(json['localVectorClock']),
      remoteVectorClock: clock(json['remoteVectorClock']),
    );
  }
}

class SyncManifestSnapshot {
  const SyncManifestSnapshot({
    required this.version,
    required this.updatedAt,
    required this.blobs,
    required this.collisions,
  });

  final int version;
  final DateTime? updatedAt;
  final List<SyncManifestBlobMetadata> blobs;
  final List<SyncManifestCollision> collisions;

  bool get hasCollisions => collisions.isNotEmpty;

  factory SyncManifestSnapshot.fromEnvelope(Map<String, dynamic> envelope) {
    final manifest = envelope['manifest'] is Map
        ? Map<String, dynamic>.from(envelope['manifest'] as Map)
        : envelope;
    final rawBlobs = manifest['blobs'];
    final rawCollisions = envelope['collisions'] ?? manifest['collisions'];
    return SyncManifestSnapshot(
      version: (manifest['version'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(
        manifest['updatedAt']?.toString() ?? '',
      )?.toUtc(),
      blobs: rawBlobs is List
          ? rawBlobs
                .whereType<Map>()
                .map(
                  (item) => SyncManifestBlobMetadata.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <SyncManifestBlobMetadata>[],
      collisions: rawCollisions is List
          ? rawCollisions
                .whereType<Map>()
                .map(
                  (item) => SyncManifestCollision.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <SyncManifestCollision>[],
    );
  }
}

class SyncPullSnapshot {
  const SyncPullSnapshot({
    required this.blobs,
    required this.manifest,
    required this.collisions,
  });

  final List<Map<String, dynamic>> blobs;
  final SyncManifestSnapshot? manifest;
  final List<SyncManifestCollision> collisions;
}

class JournalSyncApiClient {
  JournalSyncApiClient(this.transport);

  final ApiTransport transport;

  Future<SyncManifestSnapshot> syncManifest() async {
    final response = await transport.get('/api/sync/manifest');
    return SyncManifestSnapshot.fromEnvelope(transport.decodeJson(response));
  }

  Future<SyncPullSnapshot> syncPull() async {
    final response = await transport.get('/api/sync/pull');
    final body = transport.decodeJson(response);
    final rawBlobs = body['blobs'];
    final manifest = body['manifest'] is Map
        ? SyncManifestSnapshot.fromEnvelope(body)
        : null;
    final rawCollisions = body['collisions'];
    return SyncPullSnapshot(
      blobs: rawBlobs is List
          ? rawBlobs
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
      manifest: manifest,
      collisions: rawCollisions is List
          ? rawCollisions
                .whereType<Map>()
                .map(
                  (item) => SyncManifestCollision.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <SyncManifestCollision>[],
    );
  }

  Future<SyncManifestSnapshot> syncPush(Map<String, dynamic> body) async {
    final response = await transport.postJson('/api/sync/push', body: body);
    return SyncManifestSnapshot.fromEnvelope(transport.decodeJson(response));
  }

  Future<Map<String, dynamic>> syncRecoveryStatus() async =>
      transport.decodeJson(await transport.get('/api/sync/recovery?status=1'));

  Future<Map<String, dynamic>> syncRecoveryFetch() async =>
      transport.decodeJson(await transport.get('/api/sync/recovery'));

  Future<Map<String, dynamic>> syncRecoveryUpsert(
    Map<String, dynamic> envelope,
  ) async => transport.decodeJson(
    await transport.postJson(
      '/api/sync/recovery',
      body: {'envelope': envelope},
      headers: transport.headersWithIdempotency(
        base: transport.jsonHeaders,
        idempotencyKey:
            'recovery-${envelope['ownerArchiveId']}-${envelope['envelopeRevision']}',
      ),
    ),
  );

  Future<void> syncRecoveryDelete() async {
    await transport.delete('/api/sync/recovery');
  }

  Future<Map<String, dynamic>> getHealth() => health();

  Future<Map<String, dynamic>> health() async =>
      transport.decodeJson(await transport.get('/api/health'));
}
