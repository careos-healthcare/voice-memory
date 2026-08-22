import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:archiveme_mobile/core/copy_with_unset.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/features/journal/presentation/models/journal_display_presentation.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_proof_data.dart';
import 'package:archiveme_mobile/models/journal_sync_metadata.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

export 'journal_display_metadata.dart';
export 'journal_display_settings.dart';
export 'journal_proof_data.dart';
export 'journal_sync_metadata.dart';

part 'journal_entry.freezed.dart';

/// Optional hook for callers decoding persisted rows with recoverable issues.
typedef JournalEntryDataIssueHandler = void Function({
  required String entryId,
  required String issue,
});

/// A persisted voice/text journal entry composed of core content plus
/// [sync], [display], and [proof] value objects.
@Freezed(fromJson: false, toJson: false, copyWith: false)
abstract class JournalEntry with _$JournalEntry {
  const JournalEntry._();

  const factory JournalEntry.stored({
    required String id,
    required DateTime createdAt,
    required String transcript,
    required int durationSeconds,
    required Reflection reflection,
    String? localAudioPath,
    @Default(TranscriptStatus.finalTranscript)
    TranscriptStatus transcriptStatus,
    @Default(TranscriptProvenance.unknownLegacy)
    TranscriptProvenance transcriptProvenance,
    String? ownerKey,
    required JournalSyncMetadata sync,
    required JournalDisplayMetadata display,
    required JournalProofData proof,
  }) = _JournalEntry;

  /// Creates a journal entry, assembling flat parameters into composed value
  /// objects. Existing call sites keep flat named parameters; the domain
  /// model stores them in [sync], [display], and [proof].
  ///
  /// Prefer [JournalEntry.stored] or passing explicit [sync]/[display]/[proof]
  /// value objects for new code (JE-2).
  @Deprecated(
    'Use JournalEntry.stored or pass sync/display/proof value objects. '
    'The flat factory remains for legacy call sites during migration.',
  )
  factory JournalEntry({
    required String id,
    required DateTime createdAt,
    required String transcript,
    required int durationSeconds,
    required Reflection reflection,
    SyncStatus syncStatus = SyncStatus.localOnly,
    String? localAudioPath,
    TranscriptStatus transcriptStatus = TranscriptStatus.finalTranscript,
    TranscriptProvenance transcriptProvenance =
        TranscriptProvenance.unknownLegacy,
    bool treatAsNew = false,
    bool connectionApproved = false,
    bool keepExactDetails = false,
    bool keepSeparate = false,
    String? archiveThreadId,
    String? archivePackId,
    bool isPinned = false,
    DateTime? pinnedAt,
    bool isArchived = false,
    DateTime? archivedAt,
    String entryAboutness = 'about_me',
    String memorySurfacing = 'normal',
    bool preserveOriginal = false,
    String? captureContextTag,
    String? captureSource,
    ImageEvidence? imageEvidence,
    CognitiveBiomarkers? biomarkers,
    String? parentHookId,
    bool wasGrounded = false,
    VerifiedProof? verifiedProof,
    String? ownerKey,
    DateTime? updatedAt,
    int? revision,
    String? changeId,
    DateTime? deletedAt,
    int? schemaVersion,
    JournalSyncMetadata? sync,
    JournalDisplayMetadata? display,
    JournalProofData? proof,
  }) {
    final resolvedSync =
        sync ??
        JournalSyncMetadata(
          syncStatus: syncStatus,
          updatedAt: updatedAt,
          createdAt: createdAt,
          entryId: id,
          revision: revision,
          changeId: changeId,
          deletedAt: deletedAt,
          schemaVersion: schemaVersion,
        );
    final resolvedDisplay =
        display ??
        JournalDisplayMetadata(
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
          captureContextTag: captureContextTag,
          captureSource: captureSource,
        );
    final resolvedProof =
        proof ??
        JournalProofData(
          imageEvidence: imageEvidence,
          biomarkers: biomarkers,
          parentHookId: parentHookId,
          wasGrounded: wasGrounded,
          verifiedProof: verifiedProof,
        );
    return JournalEntry.stored(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: durationSeconds,
      reflection: reflection,
      localAudioPath: localAudioPath,
      transcriptStatus: transcriptStatus,
      transcriptProvenance: transcriptProvenance,
      ownerKey: ownerKey,
      sync: resolvedSync,
      display: resolvedDisplay,
      proof: resolvedProof,
    );
  }

  factory JournalEntry.fromJson(
    Map<String, dynamic> json, {
    JournalEntryDataIssueHandler? onDataIssue,
  }) {
    final reflectionJson = JsonConverters.stringMapOrEmpty(json['reflection']);
    final proof = JournalProofData.fromJson(json);
    final id = JsonConverters.stringOrEmpty(json['id']);
    if (id.isEmpty) {
      onDataIssue?.call(entryId: id, issue: 'missing_or_empty_id');
    }
    final createdAtRaw = JsonConverters.stringOrEmpty(json['createdAt']);
    final parsedCreatedAt = DateTime.tryParse(createdAtRaw);
    if (parsedCreatedAt == null) {
      onDataIssue?.call(
        entryId: id,
        issue: createdAtRaw.isEmpty ? 'missing_created_at' : 'invalid_created_at',
      );
    }
    final createdAt = parsedCreatedAt ?? DateTime.now().toUtc();
    return JournalEntry.stored(
      id: id,
      createdAt: createdAt,
      transcript: JsonConverters.stringOrEmpty(json['transcript']),
      durationSeconds: JsonConverters.intOrZero(json['durationSeconds']),
      reflection:
          proof.verifiedProof?.reflection ?? Reflection.fromJson(reflectionJson),
      localAudioPath: JsonConverters.nullableString(json['localAudioPath']),
      transcriptStatus: TranscriptStatus.fromStorage(
        JsonConverters.nullableString(json['transcriptStatus']),
      ),
      // A payload written before this field existed has no key here, and
      // `fromStorage` maps that to `unknownLegacy`. An older client that
      // round-trips the entry without understanding the field has the same
      // effect. Neither can produce a trusted value.
      transcriptProvenance: TranscriptProvenance.fromStorage(
        JsonConverters.nullableString(json['transcriptProvenance']),
      ),
      ownerKey: JsonConverters.nullableString(json['ownerKey']),
      sync: JournalSyncMetadata.fromJson(
        json,
        createdAt: createdAt,
        entryId: id,
      ),
      display: JournalDisplayMetadata.fromJson(json),
      proof: proof,
    );
  }

  static const int currentSchemaVersion = JournalSyncMetadata.currentSchemaVersion;

  // --- Delegating accessors (preserve existing call-site ergonomics) ---

  SyncStatus get syncStatus => sync.syncStatus;
  DateTime get updatedAt => sync.updatedAt;
  int get revision => sync.revision;
  String get changeId => sync.changeId;
  DateTime? get deletedAt => sync.deletedAt;
  int get schemaVersion => sync.schemaVersion;
  bool get isDeleted => sync.isDeleted;

  bool get treatAsNew => display.treatAsNew;
  bool get connectionApproved => display.connectionApproved;
  bool get keepExactDetails => display.keepExactDetails;
  bool get keepSeparate => display.keepSeparate;
  String? get archiveThreadId => display.archiveThreadId;
  String? get archivePackId => display.archivePackId;
  bool get isPinned => display.isPinned;
  DateTime? get pinnedAt => display.pinnedAt;
  bool get isArchived => display.isArchived;
  DateTime? get archivedAt => display.archivedAt;
  String get entryAboutness => display.entryAboutness;
  String get memorySurfacing => display.memorySurfacing;
  bool get preserveOriginal => display.preserveOriginal;
  String? get captureContextTag => display.captureContextTag;
  String? get captureSource => display.captureSource;

  /// UI-facing display state derived from persisted metadata.
  JournalDisplayPresentation get displayPresentation =>
      JournalDisplayPresentation.fromEntry(this);

  ImageEvidence? get imageEvidence => proof.imageEvidence;
  CognitiveBiomarkers? get biomarkers => proof.biomarkers;
  String? get parentHookId => proof.parentHookId;
  bool get wasGrounded => proof.wasGrounded;
  VerifiedProof? get verifiedProof => proof.verifiedProof;
  bool? get processingUsedOnnx => proof.processingUsedOnnx;
  bool? get processingUsedLocalStt => proof.processingUsedLocalStt;
  bool? get processingUsedGenerativeLlm => proof.processingUsedGenerativeLlm;

  String get reflectionSummary => reflection.concreteObservation.isNotEmpty
      ? reflection.concreteObservation
      : reflection.exactLanguagePattern;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'transcript': transcript,
    'durationSeconds': durationSeconds,
    'reflection': reflection.toJson(),
    if (localAudioPath != null) 'localAudioPath': localAudioPath,
    if (transcriptStatus != TranscriptStatus.finalTranscript)
      'transcriptStatus': transcriptStatus.storageValue,
    // Written unconditionally, including when it equals the default. Omitting
    // a field on its default value is what made `transcriptStatus`
    // unrecoverable: an omitted value is indistinguishable from one an older
    // build never wrote, so the two must not be allowed to collapse.
    'transcriptProvenance': transcriptProvenance.storageValue,
    if (ownerKey != null) 'ownerKey': ownerKey,
    ...sync.toJson(),
    ...display.toJson(),
    ...proof.toJson(),
  };

  /// Payload fields stored in SQLite `payload_json` — excludes indexed columns.
  Map<String, dynamic> toResidualJson() => Map.fromEntries(
    toJson().entries.where(
      (entry) =>
          !DatabaseConstants.journalEntryColumnJsonKeys.contains(entry.key),
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntry &&
          other.id == id &&
          other.createdAt == createdAt &&
          other.transcript == transcript &&
          other.durationSeconds == durationSeconds &&
          other.reflection == reflection &&
          other.localAudioPath == localAudioPath &&
          other.transcriptStatus == transcriptStatus &&
          other.transcriptProvenance == transcriptProvenance &&
          other.ownerKey == ownerKey &&
          other.sync == sync &&
          other.display == display &&
          other.proof == proof;

  @override
  int get hashCode => Object.hash(
        id,
        createdAt,
        transcript,
        durationSeconds,
        reflection,
        localAudioPath,
        transcriptStatus,
        transcriptProvenance,
        ownerKey,
        sync,
        display,
        proof,
      );

  @override
  String toString() =>
      'JournalEntry(id: $id, createdAt: $createdAt, '
      'transcriptLength: ${transcript.length}, durationSeconds: $durationSeconds, '
      'revision: $revision, syncStatus: $syncStatus)';

  JournalEntry copyWith({
    String? id,
    DateTime? createdAt,
    String? transcript,
    int? durationSeconds,
    Reflection? reflection,
    SyncStatus? syncStatus,
    Object? localAudioPath = copyWithUnset,
    TranscriptStatus? transcriptStatus,
    TranscriptProvenance? transcriptProvenance,
    bool? treatAsNew,
    bool? connectionApproved,
    bool? keepExactDetails,
    bool? keepSeparate,
    Object? archiveThreadId = copyWithUnset,
    Object? archivePackId = copyWithUnset,
    bool? isPinned,
    Object? pinnedAt = copyWithUnset,
    bool? isArchived,
    Object? archivedAt = copyWithUnset,
    String? entryAboutness,
    String? memorySurfacing,
    bool? preserveOriginal,
    Object? captureContextTag = copyWithUnset,
    Object? captureSource = copyWithUnset,
    Object? imageEvidence = copyWithUnset,
    Object? biomarkers = copyWithUnset,
    Object? parentHookId = copyWithUnset,
    bool? wasGrounded,
    Object? verifiedProof = copyWithUnset,
    Object? ownerKey = copyWithUnset,
    DateTime? updatedAt,
    int? revision,
    String? changeId,
    Object? deletedAt = copyWithUnset,
    int? schemaVersion,
    JournalSyncMetadata? sync,
    JournalDisplayMetadata? display,
    JournalProofData? proof,
  }) => JournalEntry.stored(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    transcript: transcript ?? this.transcript,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    reflection: reflection ?? this.reflection,
    localAudioPath: identical(localAudioPath, copyWithUnset)
        ? this.localAudioPath
        : localAudioPath as String?,
    transcriptStatus: transcriptStatus ?? this.transcriptStatus,
    transcriptProvenance: transcriptProvenance ?? this.transcriptProvenance,
    ownerKey: identical(ownerKey, copyWithUnset)
        ? this.ownerKey
        : ownerKey as String?,
    sync:
        sync ??
        this.sync.copyWithAnchors(
          createdAt: createdAt ?? this.createdAt,
          entryId: id ?? this.id,
          syncStatus: syncStatus,
          updatedAt: updatedAt,
          revision: revision,
          changeId: changeId,
          deletedAt: deletedAt,
          schemaVersion: schemaVersion,
        ),
    display:
        display ??
        this.display.copyWith(
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
          captureContextTag: captureContextTag,
          captureSource: captureSource,
        ),
    proof:
        proof ??
        this.proof.copyWith(
          imageEvidence: imageEvidence,
          biomarkers: biomarkers,
          parentHookId: parentHookId,
          wasGrounded: wasGrounded,
          verifiedProof: verifiedProof,
        ),
  );

  JournalEntry clearLocalAudioPath() => copyWith(localAudioPath: null);

  JournalEntry markEdited({
    DateTime Function() now = DateTime.now,
    String Function()? changeIdGenerator,
  }) {
    final ts = now().toUtc();
    return copyWith(
      updatedAt: ts,
      revision: revision + 1,
      changeId: changeIdGenerator?.call() ?? const Uuid().v4(),
    );
  }

  JournalEntry markSyncAcknowledged() =>
      copyWith(syncStatus: SyncStatus.synced);

  JournalEntry markDeleted({
    DateTime Function() now = DateTime.now,
    String Function()? changeIdGenerator,
  }) {
    final ts = now().toUtc();
    return copyWith(
      deletedAt: ts,
      updatedAt: ts,
      revision: revision + 1,
      changeId: changeIdGenerator?.call() ?? const Uuid().v4(),
      syncStatus: SyncStatus.pendingUpload,
    );
  }
}

/// Shared conflict-ordering comparator for mobile, server, and tests.
abstract class JournalSyncCompare {
  JournalSyncCompare._();

  static int compare(JournalEntry a, JournalEntry b) {
    final revisionCmp = a.revision.compareTo(b.revision);
    if (revisionCmp != 0) return revisionCmp;
    final updatedCmp = a.updatedAt.compareTo(b.updatedAt);
    if (updatedCmp != 0) return updatedCmp;
    return a.changeId.compareTo(b.changeId);
  }

  static JournalEntry winner(JournalEntry a, JournalEntry b) =>
      compare(a, b) >= 0 ? a : b;
}
