import 'package:archiveme_mobile/core/copy_with_unset.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'journal_display_metadata.freezed.dart';

/// Persisted display and organization metadata for a journal entry.
///
/// Stored in SQLite `payload_json` and sync payloads — not UI presentation logic.
/// Use [JournalDisplayPresentation] for UI-facing display state.
@Freezed(fromJson: false, toJson: false, copyWith: false)
abstract class JournalDisplayMetadata with _$JournalDisplayMetadata {
  const JournalDisplayMetadata._();

  const factory JournalDisplayMetadata({
    @Default(false) bool treatAsNew,
    @Default(false) bool connectionApproved,
    @Default(false) bool keepExactDetails,
    @Default(false) bool keepSeparate,
    String? archiveThreadId,
    String? archivePackId,
    @Default(false) bool isPinned,
    DateTime? pinnedAt,
    @Default(false) bool isArchived,
    DateTime? archivedAt,
    @Default('about_me') String entryAboutness,
    @Default('normal') String memorySurfacing,
    @Default(false) bool preserveOriginal,
    String? captureContextTag,
    String? captureSource,
  }) = _JournalDisplayMetadata;

  factory JournalDisplayMetadata.fromJson(Map<String, dynamic> json) {
    return JournalDisplayMetadata(
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
      captureSource: json['captureSource'] is String
          ? json['captureSource'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
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
    if (captureSource != null) 'captureSource': captureSource,
  };

  JournalDisplayMetadata copyWith({
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
  }) => JournalDisplayMetadata(
    treatAsNew: treatAsNew ?? this.treatAsNew,
    connectionApproved: connectionApproved ?? this.connectionApproved,
    keepExactDetails: keepExactDetails ?? this.keepExactDetails,
    keepSeparate: keepSeparate ?? this.keepSeparate,
    archiveThreadId: identical(archiveThreadId, copyWithUnset)
        ? this.archiveThreadId
        : archiveThreadId as String?,
    archivePackId: identical(archivePackId, copyWithUnset)
        ? this.archivePackId
        : archivePackId as String?,
    isPinned: isPinned ?? this.isPinned,
    pinnedAt: identical(pinnedAt, copyWithUnset)
        ? this.pinnedAt
        : pinnedAt as DateTime?,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: identical(archivedAt, copyWithUnset)
        ? this.archivedAt
        : archivedAt as DateTime?,
    entryAboutness: entryAboutness ?? this.entryAboutness,
    memorySurfacing: memorySurfacing ?? this.memorySurfacing,
    preserveOriginal: preserveOriginal ?? this.preserveOriginal,
    captureContextTag: identical(captureContextTag, copyWithUnset)
        ? this.captureContextTag
        : captureContextTag as String?,
    captureSource: identical(captureSource, copyWithUnset)
        ? this.captureSource
        : captureSource as String?,
  );
}
