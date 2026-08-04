import '../features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import '../features/media/media_attachment.dart';
import 'journal_sync_metadata.dart';
import 'local_capture_context.dart';
import 'reflection.dart';
import 'sync_status.dart';

enum SavedMomentSource { voice, typed, imported, migrated }

class SavedMomentTextEdit {
  const SavedMomentTextEdit({
    required this.editedAt,
    required this.source,
    required this.text,
  });

  final DateTime editedAt;
  final SavedMomentSource source;
  final String text;

  factory SavedMomentTextEdit.fromJson(Map<String, dynamic> json) =>
      SavedMomentTextEdit(
        editedAt:
            DateTime.tryParse(json['editedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        source:
            SavedMomentSource.values
                .where((value) => value.name == json['source'])
                .firstOrNull ??
            SavedMomentSource.migrated,
        text: json['text']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'editedAt': editedAt.toUtc().toIso8601String(),
    'source': source.name,
    'text': text,
  };
}

class SavedMomentEvidenceOffset {
  const SavedMomentEvidenceOffset({
    required this.startUtf16,
    required this.endUtf16,
    this.audioStartMs,
    this.audioEndMs,
  });

  final int startUtf16;
  final int endUtf16;
  final int? audioStartMs;
  final int? audioEndMs;

  factory SavedMomentEvidenceOffset.fromJson(Map<String, dynamic> json) =>
      SavedMomentEvidenceOffset(
        startUtf16: (json['startUtf16'] as num?)?.toInt() ?? 0,
        endUtf16: (json['endUtf16'] as num?)?.toInt() ?? 0,
        audioStartMs: (json['audioStartMs'] as num?)?.toInt(),
        audioEndMs: (json['audioEndMs'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
    'startUtf16': startUtf16,
    'endUtf16': endUtf16,
    if (audioStartMs != null) 'audioStartMs': audioStartMs,
    if (audioEndMs != null) 'audioEndMs': audioEndMs,
  };
}

class SavedMomentMigrationMetadata {
  const SavedMomentMigrationMetadata({
    required this.fromSchemaVersion,
    required this.migratedAt,
    required this.adapter,
  });

  final int fromSchemaVersion;
  final DateTime migratedAt;
  final String adapter;

  factory SavedMomentMigrationMetadata.fromJson(Map<String, dynamic> json) =>
      SavedMomentMigrationMetadata(
        fromSchemaVersion: (json['fromSchemaVersion'] as num?)?.toInt() ?? 0,
        migratedAt:
            DateTime.tryParse(json['migratedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        adapter: json['adapter']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'fromSchemaVersion': fromSchemaVersion,
    'migratedAt': migratedAt.toUtc().toIso8601String(),
    'adapter': adapter,
  };
}

/// The single persisted V1 saved-moment aggregate.
///
/// [JournalEntry] remains a source-compatible alias while older vaults migrate
/// one way into this schema.
class SavedMoment {
  SavedMoment({
    required this.id,
    required this.createdAt,
    required this.transcript,
    required this.durationSeconds,
    required this.reflection,
    this.ownerArchiveId = 'local',
    DateTime? updatedAt,
    this.source = SavedMomentSource.voice,
    Iterable<SavedMomentTextEdit> textEdits = const [],
    Iterable<SavedMomentEvidenceOffset> evidenceOffsets = const [],
    this.deletedAt,
    this.schemaVersion = currentSchemaVersion,
    this.migrationMetadata,
    this.syncStatus = SyncStatus.localOnly,
    this.localAudioPath,
    this.localAudioVaultRef,
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
    this.localCaptureContext,
    this.biomarkers,
    this.parentHookId,
    this.wasGrounded = false,
    this.syncMetadata,
    Iterable<MediaAttachment> mediaAttachments = const [],
  }) : updatedAt = (updatedAt ?? createdAt).toUtc(),
       textEdits = List.unmodifiable(textEdits),
       evidenceOffsets = List.unmodifiable(evidenceOffsets),
       mediaAttachments = immutableMediaAttachments(mediaAttachments);

  static const currentSchemaVersion = 2;
  final String id;
  final String ownerArchiveId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SavedMomentSource source;
  final String transcript;
  final List<SavedMomentTextEdit> textEdits;
  final List<SavedMomentEvidenceOffset> evidenceOffsets;
  final int durationSeconds;
  final Reflection reflection;
  final SyncStatus syncStatus;
  final DateTime? deletedAt;
  final int schemaVersion;
  final SavedMomentMigrationMetadata? migrationMetadata;

  bool get isDeleted => deletedAt != null;

  /// Legacy plaintext path loaded only for migration compatibility.
  ///
  /// New captures must use [localAudioVaultRef].
  final String? localAudioPath;

  /// Opaque app-local reference to an authenticated encrypted audio object.
  ///
  /// This is deliberately not an absolute filesystem path.
  final String? localAudioVaultRef;

  String? get localAudioReference {
    final vault = localAudioVaultRef?.trim();
    if (vault != null && vault.isNotEmpty) return vault;
    final legacy = localAudioPath?.trim();
    return legacy == null || legacy.isEmpty ? null : legacy;
  }

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

  /// Optional ambient context retained on-device and excluded from API payloads.
  final LocalCaptureContext? localCaptureContext;

  /// Optional clinical cognitive biomarkers for Phase 2 care tracking.
  final CognitiveBiomarkers? biomarkers;

  /// Links a saved response entry back to the curiosity hook it answered.
  final String? parentHookId;

  /// True when the user completed a grounding cycle before submitting a hook response.
  final bool wasGrounded;

  /// Revision metadata used to converge edits from multiple devices.
  ///
  /// Legacy entries omit it and fall back to [createdAt] during comparison.
  final JournalSyncMetadata? syncMetadata;

  /// Encrypted, app-local media associated with this entry.
  final List<MediaAttachment> mediaAttachments;

  String get reflectionSummary => reflection.concreteObservation.isNotEmpty
      ? reflection.concreteObservation
      : reflection.exactLanguagePattern;

  factory SavedMoment.fromJson(Map<String, dynamic> json) {
    final reflectionJson = json['reflection'] as Map<String, dynamic>? ?? {};
    final serverUpdatedAt = DateTime.tryParse(
      json['_serverUpdatedAt']?.toString() ?? '',
    )?.toUtc();
    final syncJson = json['_syncMeta'];
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    return SavedMoment(
      id: json['id'] as String? ?? '',
      ownerArchiveId:
          json['ownerArchiveId']?.toString().trim().isNotEmpty == true
          ? json['ownerArchiveId'].toString()
          : 'local',
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
          serverUpdatedAt ??
          createdAt,
      source:
          SavedMomentSource.values
              .where((value) => value.name == json['source'])
              .firstOrNull ??
          (json['localAudioVaultRef'] != null || json['localAudioPath'] != null
              ? SavedMomentSource.voice
              : SavedMomentSource.migrated),
      transcript: json['transcript'] as String? ?? '',
      textEdits: (json['textEdits'] as List? ?? const []).whereType<Map>().map(
        (item) => SavedMomentTextEdit.fromJson(Map<String, dynamic>.from(item)),
      ),
      evidenceOffsets: (json['evidenceOffsets'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => SavedMomentEvidenceOffset.fromJson(
              Map<String, dynamic>.from(item),
            ),
          ),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      reflection: Reflection.fromJson(reflectionJson),
      syncStatus: _parseSync(json['_syncStatus'] as String?),
      deletedAt: DateTime.tryParse(
        json['deletedAt']?.toString() ?? '',
      )?.toUtc(),
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      migrationMetadata: json['migration'] is Map
          ? SavedMomentMigrationMetadata.fromJson(
              Map<String, dynamic>.from(json['migration'] as Map),
            )
          : null,
      localAudioPath: json['localAudioPath'] as String?,
      localAudioVaultRef: json['localAudioVaultRef'] as String?,
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
      localCaptureContext: json['_localCaptureContext'] is Map
          ? LocalCaptureContext.fromJson(
              Map<String, dynamic>.from(json['_localCaptureContext'] as Map),
            )
          : null,
      biomarkers: CognitiveBiomarkers.fromJson(json['biomarkers']),
      parentHookId: json['parentHookId'] is String
          ? json['parentHookId'] as String
          : null,
      wasGrounded: json['wasGrounded'] == true,
      syncMetadata: syncJson is Map
          ? JournalSyncMetadata.fromJson(
              Map<String, dynamic>.from(syncJson),
              serverUpdatedAt: serverUpdatedAt,
            )
          : serverUpdatedAt == null
          ? null
          : JournalSyncMetadata(
              updatedAt: serverUpdatedAt,
              sourceDeviceId: 'server',
              serverUpdatedAt: serverUpdatedAt,
            ),
      mediaAttachments: (json['mediaAttachments'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => MediaAttachment.fromJson(Map<String, dynamic>.from(item)),
          ),
    );
  }

  Map<String, dynamic> toJson({bool includeLocalContext = true}) => {
    'id': id,
    'ownerArchiveId': ownerArchiveId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'source': source.name,
    'transcript': transcript,
    if (textEdits.isNotEmpty)
      'textEdits': textEdits.map((edit) => edit.toJson()).toList(),
    if (evidenceOffsets.isNotEmpty)
      'evidenceOffsets': evidenceOffsets
          .map((offset) => offset.toJson())
          .toList(),
    'durationSeconds': durationSeconds,
    'reflection': reflection.toJson(),
    '_syncStatus': _syncToString(syncStatus),
    if (deletedAt != null) 'deletedAt': deletedAt!.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    if (migrationMetadata != null) 'migration': migrationMetadata!.toJson(),
    if (includeLocalContext && localAudioPath != null)
      'localAudioPath': localAudioPath,
    if (includeLocalContext && localAudioVaultRef != null)
      'localAudioVaultRef': localAudioVaultRef,
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
    if (includeLocalContext && captureContextTag != null)
      'captureContextTag': captureContextTag,
    if (includeLocalContext && localCaptureContext?.isEmpty == false)
      '_localCaptureContext': localCaptureContext!.toJson(),
    if (biomarkers != null) 'biomarkers': biomarkers!.toJson(),
    if (parentHookId != null) 'parentHookId': parentHookId,
    if (wasGrounded) 'wasGrounded': true,
    if (syncMetadata != null) '_syncMeta': syncMetadata!.toJson(),
    if (includeLocalContext && mediaAttachments.isNotEmpty)
      'mediaAttachments': mediaAttachments
          .map((attachment) => attachment.toJson())
          .toList(),
  };

  SavedMoment copyWith({
    String? ownerArchiveId,
    DateTime? updatedAt,
    SavedMomentSource? source,
    String? transcript,
    Iterable<SavedMomentTextEdit>? textEdits,
    Iterable<SavedMomentEvidenceOffset>? evidenceOffsets,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? schemaVersion,
    SavedMomentMigrationMetadata? migrationMetadata,
    String? localAudioPath,
    bool clearLocalAudioPath = false,
    String? localAudioVaultRef,
    bool clearLocalAudioVaultRef = false,
    String? captureContextTag,
    LocalCaptureContext? localCaptureContext,
    CognitiveBiomarkers? biomarkers,
    String? parentHookId,
    bool? wasGrounded,
    SyncStatus? syncStatus,
    JournalSyncMetadata? syncMetadata,
    Iterable<MediaAttachment>? mediaAttachments,
  }) => SavedMoment(
    id: id,
    ownerArchiveId: ownerArchiveId ?? this.ownerArchiveId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    source: source ?? this.source,
    transcript: transcript ?? this.transcript,
    textEdits:
        textEdits ??
        (transcript != null && transcript != this.transcript
            ? [
                ...this.textEdits,
                SavedMomentTextEdit(
                  editedAt: (updatedAt ?? DateTime.now()).toUtc(),
                  source: source ?? this.source,
                  text: transcript,
                ),
              ]
            : this.textEdits),
    evidenceOffsets:
        evidenceOffsets ??
        (transcript != null && transcript != this.transcript
            ? const <SavedMomentEvidenceOffset>[]
            : this.evidenceOffsets),
    durationSeconds: durationSeconds,
    reflection: reflection,
    syncStatus: syncStatus ?? this.syncStatus,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    schemaVersion: schemaVersion ?? this.schemaVersion,
    migrationMetadata: migrationMetadata ?? this.migrationMetadata,
    localAudioPath:
        clearLocalAudioPath || (localAudioVaultRef?.trim().isNotEmpty ?? false)
        ? null
        : (localAudioPath ?? this.localAudioPath),
    localAudioVaultRef: clearLocalAudioVaultRef
        ? null
        : (localAudioVaultRef ?? this.localAudioVaultRef),
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
    keepExactDetails: keepExactDetails,
    keepSeparate: keepSeparate,
    archiveThreadId: archiveThreadId,
    archivePackId: archivePackId,
    isPinned: isPinned,
    pinnedAt: pinnedAt,
    isArchived: isArchived,
    archivedAt: archivedAt,
    entryAboutness: entryAboutness,
    memorySurfacing: memorySurfacing,
    preserveOriginal: preserveOriginal,
    captureContextTag: captureContextTag ?? this.captureContextTag,
    localCaptureContext: localCaptureContext ?? this.localCaptureContext,
    biomarkers: biomarkers ?? this.biomarkers,
    parentHookId: parentHookId ?? this.parentHookId,
    wasGrounded: wasGrounded ?? this.wasGrounded,
    syncMetadata: syncMetadata ?? this.syncMetadata,
    mediaAttachments: mediaAttachments ?? this.mediaAttachments,
  );

  static SyncStatus _parseSync(String? raw) {
    switch (raw) {
      case 'synced':
        return SyncStatus.synced;
      case 'pending':
        return SyncStatus.pendingUpload;
      case 'conflict':
        return SyncStatus.conflict;
      case 'error':
        return SyncStatus.error;
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
      case SyncStatus.conflict:
        return 'conflict';
      case SyncStatus.error:
        return 'error';
      case SyncStatus.localOnly:
        return 'local';
    }
  }
}

/// Source-compatible name retained while callers migrate to [SavedMoment].
typedef JournalEntry = SavedMoment;
