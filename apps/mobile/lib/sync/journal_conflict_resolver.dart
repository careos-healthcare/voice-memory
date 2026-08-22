import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/journal_sync_metadata.dart';
import 'package:archiveme_mobile/models/journal_proof_data.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:uuid/uuid.dart';

/// Optimistic concurrency relation derived from entry [revision] integers only.
enum JournalVersionRelation {
  localAhead,
  remoteAhead,
  sameRevision,
}

/// How a merge was resolved.
enum JournalConflictResolutionKind {
  noConflict,
  localWinner,
  remoteWinner,
  fieldMerged,
  policyResolved,
}

/// Explicit policy for same-revision concurrent writes (true collisions).
enum JournalCollisionPolicy {
  /// Higher [revision] wins per field; same revision uses [changeId] ordering.
  preferHigherRevision,

  /// Remote copy wins every colliding field.
  preferRemote,

  /// Local copy wins every colliding field.
  preferLocal,

  /// Field-merge non-identical values and mark [SyncStatus.conflict] for review.
  markConflict,
}

/// One field where local and remote diverged under the same revision.
class JournalFieldCollision {
  const JournalFieldCollision({
    required this.field,
    required this.localValue,
    required this.remoteValue,
  });

  final String field;
  final Object? localValue;
  final Object? remoteValue;
}

/// Result of reconciling a local/remote journal entry pair.
class JournalMergeResult {
  const JournalMergeResult({
    required this.entry,
    required this.relation,
    required this.kind,
    this.collisions = const [],
    this.requiresReview = false,
    this.shouldPersist = true,
  });

  final JournalEntry entry;
  final JournalVersionRelation relation;
  final JournalConflictResolutionKind kind;
  final List<JournalFieldCollision> collisions;
  final bool requiresReview;

  /// When `false`, the existing local row should be kept unchanged.
  final bool shouldPersist;
}

/// Revision-based optimistic concurrency with field-level merge and explicit
/// collision policies (no naive last-write-wins on timestamps).
abstract final class JournalConflictResolver {
  JournalConflictResolver._();

  static JournalVersionRelation versionRelation({
    required JournalEntry local,
    required JournalEntry remote,
  }) {
    final revisionCmp = local.revision.compareTo(remote.revision);
    if (revisionCmp > 0) return JournalVersionRelation.localAhead;
    if (revisionCmp < 0) return JournalVersionRelation.remoteAhead;
    return JournalVersionRelation.sameRevision;
  }

  static JournalMergeResult resolve({
    required JournalEntry local,
    required JournalEntry remote,
    JournalCollisionPolicy policy = JournalCollisionPolicy.preferHigherRevision,
    String Function()? changeIdGenerator,
  }) {
    assert(local.id == remote.id, 'merge requires matching entry ids');

    final relation = versionRelation(local: local, remote: remote);

    if (_entriesEquivalent(local, remote)) {
      return JournalMergeResult(
        entry: _asSynced(remote, local: local),
        relation: relation,
        kind: JournalConflictResolutionKind.noConflict,
      );
    }

    switch (relation) {
      case JournalVersionRelation.localAhead:
        return JournalMergeResult(
          entry: local,
          relation: relation,
          kind: JournalConflictResolutionKind.localWinner,
          shouldPersist: false,
        );
      case JournalVersionRelation.remoteAhead:
        final merged = _mergeFields(
          local: local,
          remote: remote,
          pickLocalOnConflict: false,
        );
        return JournalMergeResult(
          entry: merged.copyWith(syncStatus: SyncStatus.synced),
          relation: relation,
          kind: JournalConflictResolutionKind.fieldMerged,
        );
      case JournalVersionRelation.sameRevision:
        if (local.changeId == remote.changeId) {
          return JournalMergeResult(
            entry: _asSynced(remote, local: local),
            relation: relation,
            kind: JournalConflictResolutionKind.noConflict,
          );
        }
        return _resolveSameRevisionCollision(
          local: local,
          remote: remote,
          policy: policy,
          changeIdGenerator: changeIdGenerator,
        );
    }
  }

  static JournalMergeResult _resolveSameRevisionCollision({
    required JournalEntry local,
    required JournalEntry remote,
    required JournalCollisionPolicy policy,
    String Function()? changeIdGenerator,
  }) {
    final collisions = _collectCollisions(local, remote);
    switch (policy) {
      case JournalCollisionPolicy.preferRemote:
        return JournalMergeResult(
          entry: _asSynced(remote, local: local),
          relation: JournalVersionRelation.sameRevision,
          kind: JournalConflictResolutionKind.policyResolved,
          collisions: collisions,
        );
      case JournalCollisionPolicy.preferLocal:
        return JournalMergeResult(
          entry: local.copyWith(syncStatus: SyncStatus.synced),
          relation: JournalVersionRelation.sameRevision,
          kind: JournalConflictResolutionKind.policyResolved,
          collisions: collisions,
          shouldPersist: false,
        );
      case JournalCollisionPolicy.markConflict:
        final merged = _mergeFields(
          local: local,
          remote: remote,
          pickLocalOnConflict: true,
        );
        return JournalMergeResult(
          entry: merged.copyWith(
            syncStatus: SyncStatus.conflict,
            changeId: changeIdGenerator?.call() ?? const Uuid().v4(),
          ),
          relation: JournalVersionRelation.sameRevision,
          kind: JournalConflictResolutionKind.policyResolved,
          collisions: collisions,
          requiresReview: true,
        );
      case JournalCollisionPolicy.preferHigherRevision:
        final remoteWins = local.changeId.compareTo(remote.changeId) <= 0;
        if (remoteWins) {
          return JournalMergeResult(
            entry: _asSynced(remote, local: local),
            relation: JournalVersionRelation.sameRevision,
            kind: JournalConflictResolutionKind.policyResolved,
            collisions: collisions,
          );
        }
        return JournalMergeResult(
          entry: local.copyWith(syncStatus: SyncStatus.synced),
          relation: JournalVersionRelation.sameRevision,
          kind: JournalConflictResolutionKind.policyResolved,
          collisions: collisions,
          shouldPersist: false,
        );
    }
  }

  static JournalEntry _mergeFields({
    required JournalEntry local,
    required JournalEntry remote,
    required bool pickLocalOnConflict,
  }) {
    final pick = pickLocalOnConflict ? local : remote;
    final other = pickLocalOnConflict ? remote : local;

    final mergedReflection = _mergeReflection(local.reflection, remote.reflection, pickLocalOnConflict);
    final mergedDisplay = _mergeDisplay(local.display, remote.display, pickLocalOnConflict);
    final mergedProof = _mergeProof(local.proof, remote.proof, pickLocalOnConflict);

    return JournalEntry(
      id: local.id,
      createdAt: local.createdAt,
      transcript: _pick(local.transcript, remote.transcript, pickLocalOnConflict),
      durationSeconds: _pick(
        local.durationSeconds,
        remote.durationSeconds,
        pickLocalOnConflict,
      ),
      reflection: mergedReflection,
      localAudioPath: local.localAudioPath,
      transcriptStatus: _pick(
        local.transcriptStatus,
        remote.transcriptStatus,
        pickLocalOnConflict,
      ),
      ownerKey: remote.ownerKey ?? local.ownerKey,
      display: mergedDisplay,
      proof: mergedProof,
      sync: _mergeSyncMetadata(local: local, remote: remote, pick: pick, other: other),
    );
  }

  static JournalSyncMetadata _mergeSyncMetadata({
    required JournalEntry local,
    required JournalEntry remote,
    required JournalEntry pick,
    required JournalEntry other,
  }) {
    final deletedAt = _pickDeletedAt(local, remote);
    return pick.sync.copyWithAnchors(
      createdAt: local.createdAt,
      entryId: local.id,
      updatedAt: pick.updatedAt,
      revision: pick.revision,
      changeId: pick.changeId,
      deletedAt: deletedAt,
      schemaVersion: _maxSchemaVersion(local, remote),
    );
  }

  static DateTime? _pickDeletedAt(JournalEntry local, JournalEntry remote) {
    if (local.deletedAt != null && remote.deletedAt != null) {
      return local.revision >= remote.revision
          ? local.deletedAt
          : remote.deletedAt;
    }
    if (local.deletedAt != null && local.revision >= remote.revision) {
      return local.deletedAt;
    }
    if (remote.deletedAt != null && remote.revision >= local.revision) {
      return remote.deletedAt;
    }
    return null;
  }

  static Reflection _mergeReflection(
    Reflection local,
    Reflection remote,
    bool pickLocalOnConflict,
  ) {
    return Reflection(
      mood: _pick(local.mood, remote.mood, pickLocalOnConflict),
      emotionalIntensity: _pick(
        local.emotionalIntensity,
        remote.emotionalIntensity,
        pickLocalOnConflict,
      ),
      recurringThemes: _listEqual(local.recurringThemes, remote.recurringThemes)
          ? local.recurringThemes
          : (pickLocalOnConflict ? local.recurringThemes : remote.recurringThemes),
      exactLanguagePattern: _pick(
        local.exactLanguagePattern,
        remote.exactLanguagePattern,
        pickLocalOnConflict,
      ),
      concreteObservation: _pick(
        local.concreteObservation,
        remote.concreteObservation,
        pickLocalOnConflict,
      ),
      repeatedSignal: _pick(
        local.repeatedSignal,
        remote.repeatedSignal,
        pickLocalOnConflict,
      ),
      tensionOrContradiction: _pickOptional(
        local.tensionOrContradiction,
        remote.tensionOrContradiction,
        pickLocalOnConflict,
      ),
      avoidedOrVagueArea: _pickOptional(
        local.avoidedOrVagueArea,
        remote.avoidedOrVagueArea,
        pickLocalOnConflict,
      ),
      nextSmallAction: _pickOptional(
        local.nextSmallAction,
        remote.nextSmallAction,
        pickLocalOnConflict,
      ),
      patternObservations:
          _listEqual(local.patternObservations, remote.patternObservations)
          ? local.patternObservations
          : (pickLocalOnConflict
                ? local.patternObservations
                : remote.patternObservations),
    );
  }

  static JournalDisplayMetadata _mergeDisplay(
    JournalDisplayMetadata local,
    JournalDisplayMetadata remote,
    bool pickLocalOnConflict,
  ) {
    return JournalDisplayMetadata(
      treatAsNew: _pick(local.treatAsNew, remote.treatAsNew, pickLocalOnConflict),
      connectionApproved: _pick(
        local.connectionApproved,
        remote.connectionApproved,
        pickLocalOnConflict,
      ),
      keepExactDetails: _pick(
        local.keepExactDetails,
        remote.keepExactDetails,
        pickLocalOnConflict,
      ),
      keepSeparate: _pick(local.keepSeparate, remote.keepSeparate, pickLocalOnConflict),
      archiveThreadId: _pickOptional(
        local.archiveThreadId,
        remote.archiveThreadId,
        pickLocalOnConflict,
      ),
      archivePackId: _pickOptional(
        local.archivePackId,
        remote.archivePackId,
        pickLocalOnConflict,
      ),
      isPinned: _pick(local.isPinned, remote.isPinned, pickLocalOnConflict),
      pinnedAt: _pickOptional(local.pinnedAt, remote.pinnedAt, pickLocalOnConflict),
      isArchived: _pick(local.isArchived, remote.isArchived, pickLocalOnConflict),
      archivedAt: _pickOptional(
        local.archivedAt,
        remote.archivedAt,
        pickLocalOnConflict,
      ),
      entryAboutness: _pick(
        local.entryAboutness,
        remote.entryAboutness,
        pickLocalOnConflict,
      ),
      memorySurfacing: _pick(
        local.memorySurfacing,
        remote.memorySurfacing,
        pickLocalOnConflict,
      ),
      preserveOriginal: _pick(
        local.preserveOriginal,
        remote.preserveOriginal,
        pickLocalOnConflict,
      ),
      captureContextTag: _pickOptional(
        local.captureContextTag,
        remote.captureContextTag,
        pickLocalOnConflict,
      ),
      captureSource: _pickOptional(
        local.captureSource,
        remote.captureSource,
        pickLocalOnConflict,
      ),
    );
  }

  static JournalProofData _mergeProof(
    JournalProofData local,
    JournalProofData remote,
    bool pickLocalOnConflict,
  ) {
    final verifiedProof = local.verifiedProof ?? remote.verifiedProof;
    return JournalProofData(
      imageEvidence: _pickOptional(
        local.imageEvidence,
        remote.imageEvidence,
        pickLocalOnConflict,
      ),
      biomarkers: _pickOptional(
        local.biomarkers,
        remote.biomarkers,
        pickLocalOnConflict,
      ),
      parentHookId: _pickOptional(
        local.parentHookId,
        remote.parentHookId,
        pickLocalOnConflict,
      ),
      wasGrounded: local.wasGrounded || remote.wasGrounded,
      verifiedProof: verifiedProof,
    );
  }

  static T _pick<T>(T local, T remote, bool pickLocalOnConflict) {
    if (local == remote) return local;
    return pickLocalOnConflict ? local : remote;
  }

  static T? _pickOptional<T>(T? local, T? remote, bool pickLocalOnConflict) {
    if (local == remote) return local;
    if (local == null) return remote;
    if (remote == null) return local;
    return pickLocalOnConflict ? local : remote;
  }

  static JournalEntry _asSynced(JournalEntry remote, {required JournalEntry local}) {
    return remote.copyWith(
      localAudioPath: local.localAudioPath,
      ownerKey: remote.ownerKey ?? local.ownerKey,
      syncStatus: SyncStatus.synced,
    );
  }

  static int _maxSchemaVersion(JournalEntry local, JournalEntry remote) {
    return local.schemaVersion > remote.schemaVersion
        ? local.schemaVersion
        : remote.schemaVersion;
  }

  static bool _entriesEquivalent(JournalEntry a, JournalEntry b) {
    return a.revision == b.revision &&
        a.changeId == b.changeId &&
        a.transcript == b.transcript &&
        a.durationSeconds == b.durationSeconds &&
        a.deletedAt == b.deletedAt &&
        a.isPinned == b.isPinned &&
        a.isArchived == b.isArchived;
  }

  static List<JournalFieldCollision> _collectCollisions(
    JournalEntry local,
    JournalEntry remote,
  ) {
    final collisions = <JournalFieldCollision>[];
    void compareField(String name, Object? localValue, Object? remoteValue) {
      if (localValue != remoteValue) {
        collisions.add(
          JournalFieldCollision(
            field: name,
            localValue: localValue,
            remoteValue: remoteValue,
          ),
        );
      }
    }

    compareField('transcript', local.transcript, remote.transcript);
    compareField('durationSeconds', local.durationSeconds, remote.durationSeconds);
    compareField('deletedAt', local.deletedAt, remote.deletedAt);
    compareField('isPinned', local.isPinned, remote.isPinned);
    compareField('isArchived', local.isArchived, remote.isArchived);
    compareField('mood', local.reflection.mood, remote.reflection.mood);
    compareField(
      'emotionalIntensity',
      local.reflection.emotionalIntensity,
      remote.reflection.emotionalIntensity,
    );
    return collisions;
  }

  static bool _listEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
