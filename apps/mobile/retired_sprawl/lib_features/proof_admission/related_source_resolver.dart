import 'package:archiveme_mobile/features/proof_admission/archive_evidence_index.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_cache.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Chooses which earlier moments accompany a new entry into admission.
///
/// Admission decides whether a repeat or a change is *provable*; it never goes
/// looking for the moments that might prove one. Until something hands it more
/// than the entry just saved, every claim needing two distinct sources fails on
/// `<kind>_source_minimum` and the archive can only ever produce single-moment
/// observations.
///
/// This resolver is that something. It is deliberately not a matcher of
/// meaning: it offers candidates, and the verifier still has to find exact
/// quotes in them. Offering an unrelated moment therefore cannot manufacture a
/// proof — it can only waste a verification.
class RelatedSourceResolver {
  RelatedSourceResolver({
    required this.archiveScope,
    required this.ownerScope,
    ArchiveEvidenceIndex? index,
    ProofAdmissionCache? cache,
  }) : _index =
           index ??
           ArchiveEvidenceIndex(
             archiveScope: archiveScope,
             ownerScope: ownerScope,
           ),
       _cache = cache ?? ProofAdmissionCache();

  /// How many earlier moments may accompany a new entry.
  ///
  /// Small on purpose. Every extra source is another transcript the verifier
  /// must scan, and a claim resting on many weakly-related moments is exactly
  /// the over-reach the confidence bands are meant to prevent.
  static const int maxRelatedSources = 6;

  final String archiveScope;
  final String ownerScope;
  final ArchiveEvidenceIndex _index;
  final ProofAdmissionCache _cache;

  ArchiveEvidenceIndex get index => _index;

  /// Reindexes [entries], dropping anything the index no longer recognises.
  ///
  /// A full rebuild is used rather than an incremental pass because the caller
  /// hands over the whole journal anyway; the incremental path exists for
  /// callers that observe single writes.
  void sync(List<JournalEntry> entries) {
    _index.rebuild(entries.map(sourceFor));
  }

  void observe(JournalEntry entry) => _index.upsertEntry(sourceFor(entry));

  void forget(String entryId) => _index.removeEntry(entryId);

  /// Built through the shared cache so the revision here is byte-identical to
  /// the one the display gate computes. If the two ever derived it differently,
  /// a freshly admitted proof would read as stale the moment it was rendered.
  ProofSourceEntry sourceFor(JournalEntry entry) => _cache.sourceEntryFor(
    entryId: entry.id,
    archiveScope: archiveScope,
    ownerScope: ownerScope,
    transcript: entry.transcript,
    createdAt: entry.createdAt,
    sourceType: ProofSourceType.userVoiceTranscript,
    archived: entry.isArchived,
  );

  /// The sources admission should consider for [subject]: the entry itself
  /// first, then its most related earlier moments.
  ///
  /// The subject leads the list so a caller can keep treating index 0 as the
  /// moment being saved, and so a proof that cites only the new entry still
  /// behaves exactly as it did before related sources existed.
  List<ProofSourceEntry> sourcesFor(
    JournalEntry subject,
    List<JournalEntry> archive, {
    int limit = maxRelatedSources,
  }) {
    final subjectSource = sourceFor(subject);
    _index.upsertEntry(subjectSource);

    final byId = {for (final entry in archive) entry.id: entry};
    final related = _index
        .relatedSources(subject.id, limit: limit)
        .map((id) => byId[id])
        .whereType<JournalEntry>()
        .map(sourceFor)
        .toList();

    return List.unmodifiable([subjectSource, ...related]);
  }
}