import 'curated_memory_preservation_policy.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'archive_evidence_record.dart';
import 'archive_evidence_type.dart';

/// Central rules for what counts as evidence — the explicit separation
/// between raw entries, extracted facts, patterns, and generated
/// interpretation.
///
/// ArchiveMe must preserve exact evidence. Generated summaries are
/// temporary views, not the source of truth:
/// - Raw entries are never replaced or altered by any derived layer.
/// - Interpretation-typed records can never support a memory claim.
/// - Patterns reference supporting evidence ids internally, never
///   paraphrased text.
/// - "Keep exact details" entries stay individual exact evidence items
///   and are never folded into a generalized pattern.
abstract class ArchiveEvidencePolicy {
  ArchiveEvidencePolicy._();

  /// Builds typed evidence markers from saved check-in records. Pure
  /// references — no text is copied out of the raw records.
  static List<ArchiveEvidenceRecord> describe(
    List<PressureCheckInRecord> records,
  ) {
    return records
        .map(
          (r) => ArchiveEvidenceRecord(
            entryId: r.entryId,
            type: typeFor(r),
            createdAt: r.createdAt,
            userConfirmed: r.connectionApproved,
          ),
        )
        .toList();
  }

  /// The evidence type one saved record carries.
  static ArchiveEvidenceType typeFor(PressureCheckInRecord record) =>
      CuratedMemoryPreservationPolicy.evidenceTypeFor(record);

  /// The records a claim may actually stand on. Interpretation and
  /// fresh evidence are filtered out — a generated summary can never
  /// become source-of-truth evidence, no matter who hands it in.
  static List<ArchiveEvidenceRecord> sourceEvidence(
    List<ArchiveEvidenceRecord> evidence,
  ) => evidence.where((e) => e.canSupportClaims).toList();

  /// Returns [record] if it may act as source evidence, null otherwise.
  static ArchiveEvidenceRecord? asSourceEvidence(
    ArchiveEvidenceRecord record,
  ) => record.canSupportClaims ? record : null;

  /// Builds one pattern-typed evidence record from its supporting
  /// evidence. Returns null when:
  /// - fewer than [minSupport] eligible items support it, or
  /// - any supporting item is interpretation-typed (generated text can
  ///   not prop up a pattern).
  ///
  /// "Keep exact details" items are not folded in: they stay out of the
  /// generalized pattern and remain individual exact evidence.
  static ArchiveEvidenceRecord? buildPattern(
    List<ArchiveEvidenceRecord> supporting, {
    int minSupport = 2,
    DateTime? now,
  }) {
    if (supporting.any((e) => e.type == ArchiveEvidenceType.interpretation)) {
      return null;
    }
    final foldable = supporting
        .where(
          (e) =>
              e.canSupportClaims &&
              e.type != ArchiveEvidenceType.userMarkedDetail &&
              e.type != ArchiveEvidenceType.preservedOriginal,
        )
        .toList();
    if (foldable.length < minSupport) return null;
    foldable.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ArchiveEvidenceRecord(
      entryId: foldable.first.entryId,
      type: ArchiveEvidenceType.pattern,
      createdAt: foldable.first.createdAt,
      supportingEntryIds: foldable.map((e) => e.entryId).toList(),
    );
  }

  // --- Identity-summary guardrails ---

  /// Identity/personality claim shapes that memory surfaces must not
  /// use. Evidence framing speaks about evidence, not about who the
  /// user is.
  static const List<String> bannedIdentityPhrases = [
    'you are ',
    "you're ",
    'you always',
    'you never',
    'your archive believes you are',
    'this proves',
    'your personality',
    'kind of person',
  ];

  /// Whether [text] uses a broad identity/personality claim instead of
  /// evidence framing. Used by copy tests across memory surfaces.
  static bool violatesIdentityFraming(String text) {
    final lower = text.toLowerCase();
    return bannedIdentityPhrases.any(lower.contains);
  }
}
