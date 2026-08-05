import '../../models/journal_entry.dart';
import 'archive_correction.dart';
import 'proof_admission_cache.dart';
import 'proof_admission_models.dart';
import 'proof_admission_service.dart';
import 'verified_proof_view_model.dart';

/// Re-verifies a persisted proof against the archive as it exists *now*,
/// immediately before it is rendered.
///
/// Admission proves a proof was true when it was written. It cannot prove the
/// proof is still true: the user may since have edited the transcript it quotes,
/// archived the entry, or switched archives. Without this gate a stored receipt
/// would be displayed on the strength of a check that happened in the past,
/// which is the one thing the pipeline is supposed to make impossible.
///
/// It fails closed. Any outcome other than admitted yields null, and the caller
/// renders nothing at all rather than a proof it cannot stand behind.
class ProofDisplayGate {
  const ProofDisplayGate({
    CanonicalProofAdmissionService? service,
    ProofAdmissionCache? cache,
    this.activeArchiveScope = defaultArchiveScope,
    this.activeOwnerScope = defaultOwnerScope,
  })
    // The fields are private so callers cannot reach past the gate; the
    // parameters are not, so initializing formals are not available here.
    // ignore: prefer_initializing_formals
    : _service = service,
       // ignore: prefer_initializing_formals
       _cache = cache;

  static const String defaultArchiveScope = 'local_archive_v1';
  static const String defaultOwnerScope = 'local_owner_v1';

  /// Shared by default so revisions survive a widget rebuild.
  ///
  /// A per-instance cache would be discarded on every rebuild, which is the
  /// only moment it could have paid for itself. The default service shares the
  /// same cache and is itself shared, for the same reason: building a service
  /// per call would hand it an empty cache every time.
  static final ProofAdmissionCache _sharedCache = ProofAdmissionCache();
  static final CanonicalProofAdmissionService _sharedService =
      CanonicalProofAdmissionService(cache: _sharedCache);

  final CanonicalProofAdmissionService? _service;
  final ProofAdmissionCache? _cache;
  final String activeArchiveScope;
  final String activeOwnerScope;

  CanonicalProofAdmissionService get _resolved => _service ?? _sharedService;

  ProofAdmissionCache get _revisions => _cache ?? _sharedCache;

  /// The current state of one journal entry, expressed as the verifier sees it.
  ///
  /// The revision is derived from the transcript with the same hash the capture
  /// path used, so an edited transcript produces a different revision and the
  /// proof that quoted the old text reads as stale without anything having to
  /// track the edit. Hashing every entry on every rebuild is what makes this
  /// expensive, so the result is cached against the transcript it came from —
  /// a changed transcript always misses.
  ProofSourceEntry sourceFor(JournalEntry entry) => _revisions.sourceEntryFor(
    entryId: entry.id,
    archiveScope: activeArchiveScope,
    ownerScope: activeOwnerScope,
    transcript: entry.transcript,
    createdAt: entry.createdAt,
    sourceType: ProofSourceType.userVoiceTranscript,
    archived: entry.isArchived,
  );

  /// Re-runs display-time verification and reports the outcome.
  ///
  /// Exposed separately from [viewFor] so a caller that needs to distinguish
  /// "no proof" from "proof withdrawn, and why" can do so without the gate
  /// having to guess which of those the surface wants.
  ProofAdmissionResult revalidate({
    required VerifiedProof proof,
    required List<JournalEntry> entries,
  }) => _resolved.revalidateForDisplay(
    proof: proof,
    currentSources: entries.map(sourceFor).toList(),
    activeArchiveScope: activeArchiveScope,
    activeOwnerScope: activeOwnerScope,
  );

  /// The presentation model for [proof], or null when it may no longer be shown.
  VerifiedProofViewModel? viewFor({
    required VerifiedProof proof,
    required List<JournalEntry> entries,
    List<ArchiveCorrection> corrections = const [],
  }) {
    final result = revalidate(proof: proof, entries: entries);
    if (result is! ProofAdmitted) return null;

    return VerifiedProofViewModel.fromVerifiedProof(
      result.proof,
      corrections: corrections,
    );
  }

  /// The newest entry whose proof still survives revalidation, with its view.
  ///
  /// Walking backwards matters: when the latest entry's proof has gone stale the
  /// surface should fall silent rather than quietly reach further back and
  /// present an older proof as though it were the one just saved.
  ({JournalEntry entry, VerifiedProofViewModel view})? latestVerified(
    List<JournalEntry> entries, {
    List<ArchiveCorrection> corrections = const [],
  }) {
    final entry = entries
        .where((item) => item.verifiedProof != null)
        .lastOrNull;
    if (entry == null) return null;

    final view = viewFor(
      proof: entry.verifiedProof!,
      entries: entries,
      corrections: corrections,
    );
    if (view == null) return null;

    return (entry: entry, view: view);
  }
}
