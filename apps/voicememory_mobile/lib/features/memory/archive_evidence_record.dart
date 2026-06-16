import 'archive_evidence_type.dart';

/// One typed evidence marker: a reference to raw archive material plus
/// what kind of evidence it is. By construction it carries no note,
/// transcript, snippet, or summary text — the raw entry stays the only
/// holder of its own words, so no derived layer can ever replace it.
class ArchiveEvidenceRecord {
  const ArchiveEvidenceRecord({
    required this.entryId,
    required this.type,
    required this.createdAt,
    this.userConfirmed = false,
    this.supportingEntryIds = const [],
  });

  /// Safe id reference to the raw entry — never the entry itself.
  final String entryId;

  final ArchiveEvidenceType type;
  final DateTime createdAt;

  /// The user explicitly confirmed/approved this evidence connection.
  final bool userConfirmed;

  /// Pattern support: internal entry-id references only, never raw UI
  /// text. Empty for non-pattern evidence.
  final List<String> supportingEntryIds;

  int get supportingEvidenceCount => supportingEntryIds.length;

  /// Whether this record may support a memory claim.
  bool get canSupportClaims => type.canBeSourceOfTruth;

  /// Relative age bucket id for privacy-safe display: no dates leave
  /// the device-local UI as anything more specific than this.
  String timeBucketId(DateTime now) {
    final days = now.difference(createdAt).inDays;
    if (days < 1) return 'today';
    if (days <= 7) return 'this_week';
    if (days <= 30) return 'this_month';
    return 'older';
  }

  /// Consumer-facing relative time label.
  String timeBucketLabel(DateTime now) => switch (timeBucketId(now)) {
    'today' => 'Today',
    'this_week' => 'This week',
    'this_month' => 'This month',
    _ => 'Older',
  };
}
