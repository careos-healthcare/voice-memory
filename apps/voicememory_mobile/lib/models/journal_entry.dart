import '../features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'reflection.dart';
import 'sync_status.dart';

class JournalEntry {
  const JournalEntry({
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
  });

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

  String get reflectionSummary => reflection.concreteObservation.isNotEmpty
      ? reflection.concreteObservation
      : reflection.exactLanguagePattern;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final reflectionJson = json['reflection'] as Map<String, dynamic>? ?? {};
    return JournalEntry(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      transcript: json['transcript'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      reflection: Reflection.fromJson(reflectionJson),
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
  };

  JournalEntry copyWith({
    String? captureContextTag,
    CognitiveBiomarkers? biomarkers,
    String? parentHookId,
    bool? wasGrounded,
  }) => JournalEntry(
        id: id,
        createdAt: createdAt,
        transcript: transcript,
        durationSeconds: durationSeconds,
        reflection: reflection,
        syncStatus: syncStatus,
        localAudioPath: localAudioPath,
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
        biomarkers: biomarkers ?? this.biomarkers,
        parentHookId: parentHookId ?? this.parentHookId,
        wasGrounded: wasGrounded ?? this.wasGrounded,
      );

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
