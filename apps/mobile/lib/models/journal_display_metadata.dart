import 'package:archiveme_mobile/core/copy_with_unset.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:archiveme_mobile/models/app_spoken_question.dart';
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
    String? title,
    String? locationLabel,
    double? latitude,
    double? longitude,
    @Default(const <AppSpokenQuestion>[]) List<AppSpokenQuestion> aiQuestions,
  }) = _JournalDisplayMetadata;

  factory JournalDisplayMetadata.fromJson(Map<String, dynamic> json) {
    return JournalDisplayMetadata(
      treatAsNew: json['treatAsNew'] == true,
      connectionApproved: json['connectionApproved'] == true,
      keepExactDetails: json['keepExactDetails'] == true,
      keepSeparate: json['keepSeparate'] == true,
      archiveThreadId: JsonConverters.nullableString(json['archiveThreadId']),
      archivePackId: JsonConverters.nullableString(json['archivePackId']),
      isPinned: json['isPinned'] == true,
      pinnedAt: DateTime.tryParse(
        JsonConverters.stringOrEmpty(json['pinnedAt']),
      ),
      isArchived: json['isArchived'] == true,
      archivedAt: DateTime.tryParse(
        JsonConverters.stringOrEmpty(json['archivedAt']),
      ),
      entryAboutness: JsonConverters.stringOrEmpty(json['entryAboutness']).isEmpty
          ? 'about_me'
          : JsonConverters.stringOrEmpty(json['entryAboutness']),
      memorySurfacing:
          JsonConverters.stringOrEmpty(json['memorySurfacing']).isEmpty
              ? 'normal'
              : JsonConverters.stringOrEmpty(json['memorySurfacing']),
      preserveOriginal: json['preserveOriginal'] == true,
      captureContextTag: JsonConverters.nullableString(json['captureContextTag']),
      captureSource: JsonConverters.nullableString(json['captureSource']),
      title: JsonConverters.nullableString(json['title']),
      locationLabel: JsonConverters.nullableString(json['locationLabel']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      aiQuestions: AppSpokenQuestion.listFromJson(json['aiQuestions']),
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
    if (title != null && title!.trim().isNotEmpty) 'title': title,
    if (locationLabel != null && locationLabel!.trim().isNotEmpty)
      'locationLabel': locationLabel,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (aiQuestions.isNotEmpty)
      'aiQuestions': [for (final question in aiQuestions) question.toJson()],
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
    Object? title = copyWithUnset,
    Object? locationLabel = copyWithUnset,
    Object? latitude = copyWithUnset,
    Object? longitude = copyWithUnset,
    Object? aiQuestions = copyWithUnset,
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
    title: identical(title, copyWithUnset) ? this.title : title as String?,
    locationLabel: identical(locationLabel, copyWithUnset)
        ? this.locationLabel
        : locationLabel as String?,
    latitude: identical(latitude, copyWithUnset)
        ? this.latitude
        : latitude as double?,
    longitude: identical(longitude, copyWithUnset)
        ? this.longitude
        : longitude as double?,
    aiQuestions: identical(aiQuestions, copyWithUnset)
        ? this.aiQuestions
        : List<AppSpokenQuestion>.unmodifiable(
            aiQuestions as List<AppSpokenQuestion>,
          ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalDisplayMetadata &&
          other.treatAsNew == treatAsNew &&
          other.connectionApproved == connectionApproved &&
          other.keepExactDetails == keepExactDetails &&
          other.keepSeparate == keepSeparate &&
          other.archiveThreadId == archiveThreadId &&
          other.archivePackId == archivePackId &&
          other.isPinned == isPinned &&
          other.pinnedAt == pinnedAt &&
          other.isArchived == isArchived &&
          other.archivedAt == archivedAt &&
          other.entryAboutness == entryAboutness &&
          other.memorySurfacing == memorySurfacing &&
          other.preserveOriginal == preserveOriginal &&
          other.captureContextTag == captureContextTag &&
          other.captureSource == captureSource &&
          other.title == title &&
          other.locationLabel == locationLabel &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          _sameQuestions(other.aiQuestions, aiQuestions);

  @override
  int get hashCode => Object.hash(
        treatAsNew,
        connectionApproved,
        keepExactDetails,
        keepSeparate,
        archiveThreadId,
        archivePackId,
        isPinned,
        pinnedAt,
        isArchived,
        archivedAt,
        entryAboutness,
        memorySurfacing,
        preserveOriginal,
        captureContextTag,
        captureSource,
        title,
        locationLabel,
        latitude,
        longitude,
        Object.hashAll(aiQuestions),
      );
}

bool _sameQuestions(List<AppSpokenQuestion> a, List<AppSpokenQuestion> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
