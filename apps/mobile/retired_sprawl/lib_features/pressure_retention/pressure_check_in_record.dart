import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_option.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';

/// Local-only metadata saved alongside a pressure check-in journal entry.
///
/// The journal entry holds the evidence-grade transcript; this record keeps the
/// structured signal (which option, optional context, optional fear, whether
/// the user chose to stop) used by the loop-visibility, recap, and reflection
/// engines without any backend dependency.
class PressureCheckInRecord {
  const PressureCheckInRecord({
    required this.entryId,
    required this.createdAt,
    required this.optionId,
    this.contextIds = const [],
    this.fear,
    this.stopCostNote,
    this.choseToStop = false,
    this.transcript = '',
    this.treatAsNew = false,
    this.connectionApproved = false,
    this.keepExactDetails = false,
    this.keepSeparate = false,
    this.isPinned = false,
    this.archiveThreadId,
    this.archivePackId,
    this.entryAboutness = 'about_me',
    this.memorySurfacing = 'normal',
    this.preserveOriginal = false,
  });

  factory PressureCheckInRecord.fromJson(Map<String, dynamic> json) {
    final contexts = (json['contextIds'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    return PressureCheckInRecord(
      entryId: json['entryId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      optionId: json['optionId'] as String? ?? '',
      contextIds: contexts,
      fear: _optional(json['fear']),
      stopCostNote: _optional(json['stopCostNote']),
      choseToStop: json['choseToStop'] == true,
      transcript: json['transcript'] as String? ?? '',
      treatAsNew: json['treatAsNew'] == true,
      connectionApproved: json['connectionApproved'] == true,
      keepExactDetails: json['keepExactDetails'] == true,
      keepSeparate: json['keepSeparate'] == true,
      isPinned: json['isPinned'] == true,
      archiveThreadId: json['archiveThreadId'] is String
          ? json['archiveThreadId'] as String
          : null,
      archivePackId: json['archivePackId'] is String
          ? json['archivePackId'] as String
          : null,
      entryAboutness: json['entryAboutness'] as String? ?? 'about_me',
      memorySurfacing: json['memorySurfacing'] as String? ?? 'normal',
      preserveOriginal: json['preserveOriginal'] == true,
    );
  }

  /// Marker option id for records created only to carry an evidence context
  /// tag for a regular recording. Resolves to no [PressureCheckInOption], so
  /// option-based engines ignore it; context-based thread detection can use
  /// the tag, and the record holds no notes that could form belief phrases.
  static const String contextOnlyOptionId = 'context_tag';

  final String entryId;
  final DateTime createdAt;
  final String optionId;
  final List<String> contextIds;
  final String? fear;
  final String? stopCostNote;
  final bool choseToStop;
  final String transcript;

  /// "Treat this as new": metadata only — the record stays in the archive
  /// untouched, but memory/insight engines do not use it to create
  /// immediate connection claims.
  final bool treatAsNew;

  /// Ask-mode approval: the user explicitly chose Connect for this entry,
  /// so engines may use it for connection claims while scope is "ask".
  final bool connectionApproved;

  /// "Keep exact details": the record stays stored as normal but is
  /// never folded into a generic pattern or duplicate group — it can
  /// only support evidence as an individual exact item.
  final bool keepExactDetails;

  /// "Keep separate": saved apart from threads and connection claims.
  final bool keepSeparate;

  /// Pinned evidence marker — increases priority only after relevance.
  final bool isPinned;

  /// Explicit user thread assignment — stable id only.
  final String? archiveThreadId;

  /// Primary archive pack assignment — stable id only.
  final String? archivePackId;

  /// Entry aboutness — stable id only; never logged in analytics as free text.
  final String entryAboutness;

  /// Surfacing mode — stable id only; user choice, never inferred.
  final String memorySurfacing;

  /// Preserve original wording — metadata only.
  final bool preserveOriginal;

  PressureCheckInOption? get option => PressureCheckInOption.fromId(optionId);

  List<PressureContext> get contexts => contextIds
      .map(PressureContext.fromId)
      .whereType<PressureContext>()
      .toList();

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'createdAt': createdAt.toIso8601String(),
    'optionId': optionId,
    'contextIds': contextIds,
    if (fear != null) 'fear': fear,
    if (stopCostNote != null) 'stopCostNote': stopCostNote,
    'choseToStop': choseToStop,
    'transcript': transcript,
    if (treatAsNew) 'treatAsNew': true,
    if (connectionApproved) 'connectionApproved': true,
    if (keepExactDetails) 'keepExactDetails': true,
    if (keepSeparate) 'keepSeparate': true,
    if (isPinned) 'isPinned': true,
    if (archiveThreadId != null) 'archiveThreadId': archiveThreadId,
    if (archivePackId != null) 'archivePackId': archivePackId,
    if (entryAboutness != 'about_me') 'entryAboutness': entryAboutness,
    if (memorySurfacing != 'normal') 'memorySurfacing': memorySurfacing,
    if (preserveOriginal) 'preserveOriginal': true,
  };

  static String? _optional(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}