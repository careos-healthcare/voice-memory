import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/journal_entry.dart';
import '../../models/journal_sync_metadata.dart';
import '../../models/sync_status.dart';

class JournalManifestEntry {
  const JournalManifestEntry({
    required this.entryId,
    required this.updatedAt,
    required this.sourceDeviceId,
    required this.contentHash,
    required this.vectorClock,
  });

  final String entryId;
  final DateTime updatedAt;
  final String sourceDeviceId;
  final String contentHash;
  final Map<String, int> vectorClock;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entryId': entryId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'sourceDeviceId': sourceDeviceId,
    'contentHash': contentHash,
    if (vectorClock.isNotEmpty) 'vectorClock': vectorClock,
  };

  factory JournalManifestEntry.fromJson(Map<String, dynamic> json) {
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
    return JournalManifestEntry(
      entryId: json['entryId']?.toString() ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sourceDeviceId: json['sourceDeviceId']?.toString() ?? '',
      contentHash: json['contentHash']?.toString() ?? '',
      vectorClock: Map<String, int>.unmodifiable(clock),
    );
  }
}

class JournalSyncManifest {
  const JournalSyncManifest({
    required this.version,
    required this.generatedAt,
    required this.deviceId,
    required this.entries,
  });

  final int version;
  final DateTime generatedAt;
  final String deviceId;
  final Map<String, JournalManifestEntry> entries;

  factory JournalSyncManifest.fromEntries({
    required Iterable<JournalEntry> entries,
    required String deviceId,
    required DateTime generatedAt,
    int version = 1,
  }) {
    return JournalSyncManifest(
      version: version,
      generatedAt: generatedAt.toUtc(),
      deviceId: deviceId,
      entries: Map<String, JournalManifestEntry>.unmodifiable({
        for (final entry in entries)
          entry.id: JournalSyncConflictResolver.manifestEntry(
            entry,
            fallbackDeviceId: deviceId,
          ),
      }),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
    'entries': entries.map(
      (entryId, entry) => MapEntry(entryId, entry.toJson()),
    ),
  };

  factory JournalSyncManifest.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = <String, JournalManifestEntry>{};
    if (rawEntries is Map) {
      for (final item in rawEntries.entries) {
        if (item.value is Map) {
          final entry = JournalManifestEntry.fromJson(
            Map<String, dynamic>.from(item.value as Map),
          );
          entries[item.key.toString()] = entry;
        }
      }
    }
    return JournalSyncManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deviceId: json['deviceId']?.toString() ?? '',
      entries: Map<String, JournalManifestEntry>.unmodifiable(entries),
    );
  }
}

class JournalMergeCollision {
  const JournalMergeCollision({
    required this.entryId,
    required this.localHash,
    required this.remoteHash,
    required this.winnerDeviceId,
    required this.vectorClockRelation,
  });

  final String entryId;
  final String localHash;
  final String remoteHash;
  final String winnerDeviceId;
  final VectorClockRelation vectorClockRelation;
}

class JournalMergeResult {
  const JournalMergeResult({
    required this.entries,
    required this.collisions,
    required this.localWinnerIds,
  });

  final List<JournalEntry> entries;
  final List<JournalMergeCollision> collisions;
  final Set<String> localWinnerIds;
}

class JournalSyncConflictResolver {
  const JournalSyncConflictResolver._();

  static JournalEntry stampLocalWrite({
    required JournalEntry entry,
    required JournalEntry? previous,
    required String deviceId,
    required DateTime updatedAt,
  }) {
    final previousClock =
        previous?.syncMetadata?.vectorClock ??
        entry.syncMetadata?.vectorClock ??
        const <String, int>{};
    return entry.copyWith(
      updatedAt: updatedAt.toUtc(),
      syncStatus: previous == null
          ? SyncStatus.localOnly
          : SyncStatus.pendingUpload,
      syncMetadata: JournalSyncMetadata(
        updatedAt: updatedAt.toUtc(),
        sourceDeviceId: deviceId,
        vectorClock: incrementVectorClock(previousClock, deviceId),
      ),
    );
  }

  static JournalMergeResult merge({
    required Iterable<JournalEntry> localEntries,
    required Iterable<JournalEntry> remoteEntries,
    required String localDeviceId,
  }) {
    final localOwnerIds = localEntries
        .map((entry) => entry.ownerArchiveId)
        .where((owner) => owner.isNotEmpty)
        .toSet();
    final remoteOwnerIds = remoteEntries
        .map((entry) => entry.ownerArchiveId)
        .where((owner) => owner.isNotEmpty)
        .toSet();
    if (localOwnerIds.length > 1 ||
        remoteOwnerIds.length > 1 ||
        (localOwnerIds.isNotEmpty &&
            remoteOwnerIds.any((owner) => !localOwnerIds.contains(owner)))) {
      throw StateError('Cross-account journal merge rejected.');
    }
    final localById = <String, JournalEntry>{
      for (final entry in localEntries) entry.id: entry,
    };
    final remoteById = <String, JournalEntry>{};
    for (final entry in remoteEntries) {
      final previous = remoteById[entry.id];
      remoteById[entry.id] = previous == null
          ? entry
          : _pickWinner(
              previous,
              entry,
              leftFallbackDeviceId: 'server',
              rightFallbackDeviceId: 'server',
            );
    }

    final merged = <JournalEntry>[];
    final collisions = <JournalMergeCollision>[];
    final localWinnerIds = <String>{};
    final ids = <String>{...localById.keys, ...remoteById.keys}.toList()
      ..sort();

    for (final id in ids) {
      final local = localById[id];
      final remote = remoteById[id];
      if (local == null) {
        merged.add(_asSynced(remote!, localOnlySource: null));
        continue;
      }
      if (remote == null) {
        merged.add(local);
        localWinnerIds.add(id);
        continue;
      }

      final localManifest = manifestEntry(
        local,
        fallbackDeviceId: localDeviceId,
      );
      final remoteManifest = manifestEntry(remote, fallbackDeviceId: 'server');
      final relation = compareVectorClocks(
        localManifest.vectorClock,
        remoteManifest.vectorClock,
      );
      final sameContent =
          localManifest.contentHash == remoteManifest.contentHash;
      final winner = _pickWinner(
        local,
        remote,
        leftFallbackDeviceId: localDeviceId,
        rightFallbackDeviceId: 'server',
      );
      final localWon = identical(winner, local);

      if (!sameContent) {
        collisions.add(
          JournalMergeCollision(
            entryId: id,
            localHash: localManifest.contentHash,
            remoteHash: remoteManifest.contentHash,
            winnerDeviceId: manifestEntry(
              winner,
              fallbackDeviceId: localWon ? localDeviceId : 'server',
            ).sourceDeviceId,
            vectorClockRelation: relation,
          ),
        );
      }

      if (sameContent) {
        merged.add(_asSynced(winner, localOnlySource: local));
      } else if (localWon) {
        localWinnerIds.add(id);
        merged.add(
          _copyWithLocalOnly(
            local.copyWith(syncStatus: SyncStatus.pendingUpload),
            local,
          ),
        );
      } else {
        merged.add(_asSynced(remote, localOnlySource: local));
      }
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return JournalMergeResult(
      entries: List<JournalEntry>.unmodifiable(merged),
      collisions: List<JournalMergeCollision>.unmodifiable(collisions),
      localWinnerIds: Set<String>.unmodifiable(localWinnerIds),
    );
  }

  static JournalManifestEntry manifestEntry(
    JournalEntry entry, {
    required String fallbackDeviceId,
  }) {
    final metadata = entry.syncMetadata;
    return JournalManifestEntry(
      entryId: entry.id,
      updatedAt: (metadata?.updatedAt ?? entry.createdAt).toUtc(),
      sourceDeviceId: metadata?.sourceDeviceId.trim().isNotEmpty == true
          ? metadata!.sourceDeviceId
          : fallbackDeviceId,
      contentHash: contentHash(entry),
      vectorClock: metadata?.vectorClock ?? const <String, int>{},
    );
  }

  static String contentHash(JournalEntry entry) {
    final canonical = entry.toJson(includeLocalContext: false)
      ..remove('_syncStatus')
      ..remove('_syncMeta')
      ..remove('localAudioPath')
      ..remove('localAudioVaultRef')
      ..remove('_serverUpdatedAt');
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static JournalEntry _pickWinner(
    JournalEntry left,
    JournalEntry right, {
    required String leftFallbackDeviceId,
    required String rightFallbackDeviceId,
  }) {
    final leftManifest = manifestEntry(
      left,
      fallbackDeviceId: leftFallbackDeviceId,
    );
    final rightManifest = manifestEntry(
      right,
      fallbackDeviceId: rightFallbackDeviceId,
    );
    final relation = compareVectorClocks(
      leftManifest.vectorClock,
      rightManifest.vectorClock,
    );
    if (relation == VectorClockRelation.dominates) return left;
    if (relation == VectorClockRelation.isDominated) return right;

    final timestampComparison = leftManifest.updatedAt.compareTo(
      rightManifest.updatedAt,
    );
    if (timestampComparison != 0) {
      return timestampComparison > 0 ? left : right;
    }
    final deviceComparison = leftManifest.sourceDeviceId.compareTo(
      rightManifest.sourceDeviceId,
    );
    if (deviceComparison != 0) return deviceComparison > 0 ? left : right;
    final hashComparison = leftManifest.contentHash.compareTo(
      rightManifest.contentHash,
    );
    return hashComparison >= 0 ? left : right;
  }

  static JournalEntry _asSynced(
    JournalEntry winner, {
    required JournalEntry? localOnlySource,
  }) => _copyWithLocalOnly(
    winner.copyWith(syncStatus: SyncStatus.synced),
    localOnlySource,
  );

  static JournalEntry _copyWithLocalOnly(
    JournalEntry source,
    JournalEntry? localOnlySource,
  ) {
    return JournalEntry(
      id: source.id,
      ownerArchiveId: source.ownerArchiveId,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
      source: source.source,
      transcript: source.transcript,
      textEdits: source.textEdits,
      evidenceOffsets: source.evidenceOffsets,
      durationSeconds: source.durationSeconds,
      reflection: source.reflection,
      syncStatus: source.syncStatus,
      deletedAt: source.deletedAt,
      schemaVersion: source.schemaVersion,
      migrationMetadata: source.migrationMetadata,
      localAudioPath: localOnlySource?.localAudioPath ?? source.localAudioPath,
      localAudioVaultRef:
          localOnlySource?.localAudioVaultRef ?? source.localAudioVaultRef,
      treatAsNew: source.treatAsNew,
      connectionApproved: source.connectionApproved,
      keepExactDetails: source.keepExactDetails,
      keepSeparate: source.keepSeparate,
      archiveThreadId: source.archiveThreadId,
      archivePackId: source.archivePackId,
      isPinned: source.isPinned,
      pinnedAt: source.pinnedAt,
      isArchived: source.isArchived,
      archivedAt: source.archivedAt,
      entryAboutness: source.entryAboutness,
      memorySurfacing: source.memorySurfacing,
      preserveOriginal: source.preserveOriginal,
      captureContextTag:
          localOnlySource?.captureContextTag ?? source.captureContextTag,
      localCaptureContext:
          localOnlySource?.localCaptureContext ?? source.localCaptureContext,
      biomarkers: source.biomarkers,
      parentHookId: source.parentHookId,
      wasGrounded: source.wasGrounded,
      syncMetadata: source.syncMetadata,
    );
  }
}
