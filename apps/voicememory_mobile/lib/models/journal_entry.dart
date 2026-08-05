import 'package:uuid/uuid.dart';

import '../features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import '../features/proof_admission/proof_admission_models.dart';
import 'reflection.dart';
import 'sync_status.dart';

/// Sentinel used by [JournalEntry.copyWith] to distinguish "caller did not
/// pass this argument" from "caller explicitly passed null", so nullable
/// fields can be cleared without a lossy `value ?? existingValue` contract.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

/// Wraps a possibly-null value that a caller explicitly wants to set,
/// including setting it to null. Passing nothing to a [JournalEntry.copyWith]
/// nullable parameter leaves the field untouched; passing
/// `JournalValue<String?>(null)` (or the field-specific `clearX()` helper)
/// explicitly clears it.
class JournalValue<T> {
  const JournalValue(this.value);
  final T value;
}

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
    required this.durationSeconds,
    required this.reflection,
    this.syncStatus = SyncStatus.localOnly,
    this.localAudioPath,
    this.treatAsNew = false,
    this.connectionApproved = false,
    this.keepExactDetails = false,
    this.keepSeparate = false,
    this.archiveThreadId,
    this.archivePackId,
    this.isPinned = false,
    this.pinnedAt,
    this.isArchived = false,
    this.archivedAt,
    this.entryAboutness = 'about_me',
    this.memorySurfacing = 'normal',
    this.preserveOriginal = false,
    this.captureContextTag,
    this.biomarkers,
    this.parentHookId,
    this.wasGrounded = false,
    this.verifiedProof,
    this.ownerKey,
    DateTime? updatedAt,
    int? revision,
    String? changeId,
    this.deletedAt,
    int? schemaVersion,
  }) : updatedAt = (updatedAt ?? createdAt).toUtc(),
       revision = (revision == null || revision < 1) ? 1 : revision,
       changeId = (changeId == null || changeId.isEmpty)
           ? JournalSyncIds.deterministicChangeId(
               id: id,
               createdAt: createdAt,
               revision: (revision == null || revision < 1) ? 1 : revision,
             )
           : changeId,
       schemaVersion = schemaVersion ?? currentSchemaVersion;

  /// Bumped whenever the persisted-entry schema gains fields that older
  /// installs must migrate on read. Migration is idempotent: re-running it
  /// against an already-migrated entry is a no-op.
  static const int currentSchemaVersion = 2;

  final String id;
  final DateTime createdAt;
  final String transcript;
  final int durationSeconds;
  final Reflection reflection;
  final SyncStatus syncStatus;
  final String? localAudioPath;

  /// "Treat this as new": metadata only — the entry stays in the archive
  /// and its text is untouched, but memory/insight engines do not use it
  /// to create immediate connection claims.
  final bool treatAsNew;

  /// Ask-mode approval: the user explicitly chose Connect for this entry.
  final bool connectionApproved;

  /// "Keep exact details": metadata only — the entry stays stored and
  /// searchable as normal, but it is never compressed into a generic
  /// memory summary; it may support future evidence only as an exact
  /// evidence item.
  final bool keepExactDetails;

  /// "Keep separate": metadata only — saved apart from threads and
  /// connection suggestions; still findable in archive and search.
  final bool keepSeparate;

  /// Explicit user thread assignment — stable id only, never logged.
  final String? archiveThreadId;

  /// Primary archive pack assignment — stable id only, never logged.
  final String? archivePackId;

  /// Pinned / saved evidence: metadata only — a pinned entry is easier
  /// to find, nothing more. Pinning never changes memory scope,
  /// authority, or the entry text.
  final bool isPinned;

  /// When the entry was pinned; null when not pinned.
  final DateTime? pinnedAt;

  /// Archived: metadata only — the entry stays stored with its text
  /// untouched, but it is hidden from the default archive list and
  /// search unless the Archived filter is selected, and it does not
  /// back new visible memory claims by default.
  final bool isArchived;

  /// When the entry was archived; null when not archived.
  final DateTime? archivedAt;

  /// Whether this entry is personal evidence — stable id only (`about_me`, etc.).
  final String entryAboutness;

  /// User-controlled resurfacing preference — stable id only.
  final String memorySurfacing;

  /// Preserve original wording as evidence — metadata only.
  final bool preserveOriginal;

  /// Optional local context tag — stable id only, never shared externally.
  final String? captureContextTag;

  /// Optional clinical cognitive biomarkers for Phase 2 care tracking.
  final CognitiveBiomarkers? biomarkers;

  /// Links a saved response entry back to the curiosity hook it answered.
  final String? parentHookId;

  /// True when the user completed a grounding cycle before submitting a hook response.
  final bool wasGrounded;

  /// The only model-derived proof object approved for customer-facing use.
  /// Legacy entries may be null and must be revalidated before resurfacing.
  final VerifiedProof? verifiedProof;

  /// The signed-in account (userId) this entry is stamped with, set once at
  /// creation time. Null means "unowned" — either created before this field
  /// existed, or created while signed out. Used by [JournalOwnershipGuard] to
  /// stop entries from one account being uploaded under a different
  /// account's session when a device is shared or reused.
  final String? ownerKey;

  /// Immutable. Never used as an update/version timestamp — see [updatedAt].
  // (createdAt itself declared above, documented here for clarity.)

  /// Mutable, UTC. Updated on every meaningful local edit. Defaults to
  /// [createdAt] for newly-created and migrated-legacy entries.
  final DateTime updatedAt;

  /// Positive, monotonically-increasing per-entry edit counter. Starts at 1.
  /// Used as the primary conflict-resolution signal — see [JournalSyncCompare].
  final int revision;

  /// Stable, deterministic conflict tie-breaker. Two entries with the same
  /// [id] and [revision] resolve deterministically by comparing this value.
  /// Generated once per meaningful edit; migrated legacy entries get a
  /// value deterministically derived from (id, createdAt, revision) so
  /// re-running migration never produces a different value.
  final String changeId;

  /// Tombstone marker. Non-null means this entry was locally deleted and is
  /// being retained (hidden from normal queries) until the server has
  /// acknowledged the deletion and the retention window has elapsed.
  final DateTime? deletedAt;

  /// Schema version this entry was constructed/migrated against.
  final int schemaVersion;

  /// True once [deletedAt] is set — hidden from all normal UI/eligibility
  /// queries by [JournalStore].
  bool get isDeleted => deletedAt != null;

  String get reflectionSummary => reflection.concreteObservation.isNotEmpty
      ? reflection.concreteObservation
      : reflection.exactLanguagePattern;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final reflectionJson = json['reflection'] as Map<String, dynamic>? ?? {};
    final proofJson = json['verifiedProof'];
    final verifiedProof = proofJson is Map
        ? VerifiedProof.fromJson(Map<String, dynamic>.from(proofJson))
        : null;
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now().toUtc();
    // Legacy migration: an entry with no persisted revision/changeId is
    // schema v1. `updatedAt` defaults to `createdAt`, `revision` starts at
    // 1, and `changeId` is derived deterministically below (never randomly)
    // so repeated migration of the same legacy JSON is idempotent and never
    // discards or corrupts the entry.
    final revision = (json['revision'] as num?)?.toInt();
    final changeId = json['changeId'] as String?;
    return JournalEntry(
      id: json['id'] as String? ?? '',
      createdAt: createdAt,
      transcript: json['transcript'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      reflection:
          verifiedProof?.reflection ?? Reflection.fromJson(reflectionJson),
      syncStatus: _parseSync(json['_syncStatus'] as String?),
      localAudioPath: json['localAudioPath'] as String?,
      treatAsNew: json['treatAsNew'] == true,
      connectionApproved: json['connectionApproved'] == true,
      keepExactDetails: json['keepExactDetails'] == true,
      keepSeparate: json['keepSeparate'] == true,
      archiveThreadId: json['archiveThreadId'] is String
          ? json['archiveThreadId'] as String
          : null,
      archivePackId: json['archivePackId'] is String
          ? json['archivePackId'] as String
          : null,
      isPinned: json['isPinned'] == true,
      pinnedAt: DateTime.tryParse(json['pinnedAt'] as String? ?? ''),
      isArchived: json['isArchived'] == true,
      archivedAt: DateTime.tryParse(json['archivedAt'] as String? ?? ''),
      entryAboutness: json['entryAboutness'] as String? ?? 'about_me',
      memorySurfacing: json['memorySurfacing'] as String? ?? 'normal',
      preserveOriginal: json['preserveOriginal'] == true,
      captureContextTag: json['captureContextTag'] is String
          ? json['captureContextTag'] as String
          : null,
      biomarkers: CognitiveBiomarkers.fromJson(json['biomarkers']),
      parentHookId: json['parentHookId'] is String
          ? json['parentHookId'] as String
          : null,
      wasGrounded: json['wasGrounded'] == true,
      verifiedProof: verifiedProof,
      ownerKey: json['ownerKey'] is String ? json['ownerKey'] as String : null,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      revision: revision,
      changeId: changeId,
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      schemaVersion: (json['schemaVersion'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'transcript': transcript,
    'durationSeconds': durationSeconds,
    'reflection': reflection.toJson(),
    '_syncStatus': _syncToString(syncStatus),
    if (localAudioPath != null) 'localAudioPath': localAudioPath,
    if (treatAsNew) 'treatAsNew': true,
    if (connectionApproved) 'connectionApproved': true,
    if (keepExactDetails) 'keepExactDetails': true,
    if (keepSeparate) 'keepSeparate': true,
    if (archiveThreadId != null) 'archiveThreadId': archiveThreadId,
    if (archivePackId != null) 'archivePackId': archivePackId,
    if (isPinned) 'isPinned': true,
    if (pinnedAt != null) 'pinnedAt': pinnedAt!.toIso8601String(),
    if (isArchived) 'isArchived': true,
    if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
    if (entryAboutness != 'about_me') 'entryAboutness': entryAboutness,
    if (memorySurfacing != 'normal') 'memorySurfacing': memorySurfacing,
    if (preserveOriginal) 'preserveOriginal': true,
    if (captureContextTag != null) 'captureContextTag': captureContextTag,
    if (biomarkers != null) 'biomarkers': biomarkers!.toJson(),
    if (parentHookId != null) 'parentHookId': parentHookId,
    if (wasGrounded) 'wasGrounded': true,
    if (verifiedProof != null) 'verifiedProof': verifiedProof!.toJson(),
    if (ownerKey != null) 'ownerKey': ownerKey,
    'updatedAt': updatedAt.toIso8601String(),
    'revision': revision,
    'changeId': changeId,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  /// Lossless, authoritative mutation. Every field on [JournalEntry] is
  /// represented here. Non-nullable fields follow the ordinary
  /// `value ?? existing` contract (there is no ambiguity: a non-nullable
  /// field can never be "cleared"). Nullable fields use the [_unset]
  /// sentinel so that omitting an argument preserves the existing value —
  /// including preserving an existing null — while explicitly passing
  /// `null` clears it. This is what makes partial reconstructions (audio
  /// cleanup, sync-status updates, remote merges, memory-flag updates)
  /// lossless: every caller can now express "leave everything else exactly
  /// as-is" instead of manually re-listing every field.
  JournalEntry copyWith({
    String? id,
    DateTime? createdAt,
    String? transcript,
    int? durationSeconds,
    Reflection? reflection,
    SyncStatus? syncStatus,
    Object? localAudioPath = _unset,
    bool? treatAsNew,
    bool? connectionApproved,
    bool? keepExactDetails,
    bool? keepSeparate,
    Object? archiveThreadId = _unset,
    Object? archivePackId = _unset,
    bool? isPinned,
    Object? pinnedAt = _unset,
    bool? isArchived,
    Object? archivedAt = _unset,
    String? entryAboutness,
    String? memorySurfacing,
    bool? preserveOriginal,
    Object? captureContextTag = _unset,
    Object? biomarkers = _unset,
    Object? parentHookId = _unset,
    bool? wasGrounded,
    Object? verifiedProof = _unset,
    Object? ownerKey = _unset,
    DateTime? updatedAt,
    int? revision,
    String? changeId,
    Object? deletedAt = _unset,
    int? schemaVersion,
  }) => JournalEntry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    transcript: transcript ?? this.transcript,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    reflection: reflection ?? this.reflection,
    syncStatus: syncStatus ?? this.syncStatus,
    localAudioPath: identical(localAudioPath, _unset)
        ? this.localAudioPath
        : localAudioPath as String?,
    treatAsNew: treatAsNew ?? this.treatAsNew,
    connectionApproved: connectionApproved ?? this.connectionApproved,
    keepExactDetails: keepExactDetails ?? this.keepExactDetails,
    keepSeparate: keepSeparate ?? this.keepSeparate,
    archiveThreadId: identical(archiveThreadId, _unset)
        ? this.archiveThreadId
        : archiveThreadId as String?,
    archivePackId: identical(archivePackId, _unset)
        ? this.archivePackId
        : archivePackId as String?,
    isPinned: isPinned ?? this.isPinned,
    pinnedAt: identical(pinnedAt, _unset)
        ? this.pinnedAt
        : pinnedAt as DateTime?,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: identical(archivedAt, _unset)
        ? this.archivedAt
        : archivedAt as DateTime?,
    entryAboutness: entryAboutness ?? this.entryAboutness,
    memorySurfacing: memorySurfacing ?? this.memorySurfacing,
    preserveOriginal: preserveOriginal ?? this.preserveOriginal,
    captureContextTag: identical(captureContextTag, _unset)
        ? this.captureContextTag
        : captureContextTag as String?,
    biomarkers: identical(biomarkers, _unset)
        ? this.biomarkers
        : biomarkers as CognitiveBiomarkers?,
    parentHookId: identical(parentHookId, _unset)
        ? this.parentHookId
        : parentHookId as String?,
    wasGrounded: wasGrounded ?? this.wasGrounded,
    verifiedProof: identical(verifiedProof, _unset)
        ? this.verifiedProof
        : verifiedProof as VerifiedProof?,
    ownerKey: identical(ownerKey, _unset) ? this.ownerKey : ownerKey as String?,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
    changeId: changeId ?? this.changeId,
    deletedAt: identical(deletedAt, _unset)
        ? this.deletedAt
        : deletedAt as DateTime?,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );

  /// Dedicated operation for clearing [localAudioPath] without disturbing
  /// any other field (biomarkers, parentHookId, wasGrounded, verifiedProof,
  /// ownerKey, archive/thread/pack assignment, pin/archive state, or sync
  /// metadata). Does not itself count as a customer edit — see
  /// [markSyncAcknowledged] vs [markEdited].
  JournalEntry clearLocalAudioPath() => copyWith(localAudioPath: null);

  /// Marks a meaningful local edit: bumps [revision], refreshes [updatedAt]
  /// (UTC) and generates a fresh [changeId]. Use for every user-visible
  /// content/metadata change. Do NOT use this for sync bookkeeping alone
  /// (see [markSyncAcknowledged]), which must not appear as a customer edit.
  JournalEntry markEdited({DateTime Function() now = DateTime.now}) {
    final ts = now().toUtc();
    return copyWith(
      updatedAt: ts,
      revision: revision + 1,
      changeId: const Uuid().v4(),
    );
  }

  /// Acknowledges that the server has durably stored this exact revision.
  /// Only [syncStatus] changes — updatedAt/revision/changeId are left
  /// untouched so acknowledging sync is never mistaken for a customer edit.
  JournalEntry markSyncAcknowledged() =>
      copyWith(syncStatus: SyncStatus.synced);

  /// Creates a tombstone: the entry is hidden from normal queries but
  /// retained (with all its fields intact) until the server acknowledges
  /// the deletion and the retention window elapses. This is a meaningful
  /// edit, so revision/updatedAt/changeId advance like any other mutation.
  JournalEntry markDeleted({DateTime Function() now = DateTime.now}) {
    final ts = now().toUtc();
    return copyWith(
      deletedAt: ts,
      updatedAt: ts,
      revision: revision + 1,
      changeId: const Uuid().v4(),
      syncStatus: SyncStatus.pendingUpload,
    );
  }

  static SyncStatus _parseSync(String? raw) {
    switch (raw) {
      case 'synced':
        return SyncStatus.synced;
      case 'pending':
        return SyncStatus.pendingUpload;
      default:
        return SyncStatus.localOnly;
    }
  }

  static String _syncToString(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pendingUpload:
        return 'pending';
      default:
        return 'local';
    }
  }
}

/// Deterministic id generation used only for legacy-entry migration, so
/// migrating the same JSON twice (e.g. a read before the migrated form is
/// ever written back to disk) always produces the same [changeId].
abstract class JournalSyncIds {
  JournalSyncIds._();

  static const _migrationNamespace = '6c9c53f2-6c39-4c7a-9b3a-9d2f9c8f3a11';

  static String deterministicChangeId({
    required String id,
    required DateTime createdAt,
    required int revision,
  }) {
    return const Uuid().v5(
      _migrationNamespace,
      'archiveme-legacy:$id:${createdAt.toUtc().toIso8601String()}:$revision',
    );
  }
}

/// Shared conflict-ordering comparator. The same three-step comparison must
/// be used on mobile, server and tests so both sides agree on which of two
/// conflicting revisions of the same logical entry wins:
///   1. Higher [JournalEntry.revision] wins.
///   2. Later [JournalEntry.updatedAt] wins.
///   3. Deterministic [JournalEntry.changeId] string comparison (lexically
///      greater wins) as a final, stable tie-breaker.
abstract class JournalSyncCompare {
  JournalSyncCompare._();

  /// Returns a positive number if [a] should win over [b], negative if [b]
  /// should win, or 0 only when both entries are field-for-field identical
  /// on every ordering key (same revision, updatedAt and changeId).
  static int compare(JournalEntry a, JournalEntry b) {
    final revisionCmp = a.revision.compareTo(b.revision);
    if (revisionCmp != 0) return revisionCmp;
    final updatedCmp = a.updatedAt.compareTo(b.updatedAt);
    if (updatedCmp != 0) return updatedCmp;
    return a.changeId.compareTo(b.changeId);
  }

  /// Convenience: the entry that should be kept when [a] and [b] represent
  /// the same logical entry id but disagree.
  static JournalEntry winner(JournalEntry a, JournalEntry b) =>
      compare(a, b) >= 0 ? a : b;
}
