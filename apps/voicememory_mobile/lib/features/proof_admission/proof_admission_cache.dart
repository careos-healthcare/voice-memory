import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

import '../../security/user_content_safety.dart';
import 'proof_admission_analytics.dart';
import 'proof_admission_models.dart';
import 'proof_candidate.dart';

/// Computes a stable digest of one transcript.
typedef ProofTranscriptDigest = String Function(String transcript);

/// The measured phases of the admission pipeline.
///
/// Each phase carries the id-shaped token it reports under, so a phase can be
/// named in analytics without a second naming scheme growing next to this one.
enum ProofPipelinePhase {
  parse('parse'),
  structuralValidation('structural_validation'),
  evidenceVerification('evidence_verification'),
  confidenceScoring('confidence_scoring'),
  ranking('ranking'),
  proofDetailLoad('proof_detail_load');

  const ProofPipelinePhase(this.token);

  final String token;
}

/// The structural facts display-time revalidation reads about one source entry.
///
/// Deliberately holds no transcript, quote or statement: ids, digests, flags and
/// dates only. Everything here is either something the caller already knew or a
/// hash of something it already had, so a revision record can be held in memory
/// and compared freely without becoming a second copy of the archive.
///
/// [transcriptFingerprint] is the expensive value: it is the same digest the
/// verifier stamps into [VerifiedEvidenceSnapshot.transcriptFingerprint], and
/// recomputing it for every citation on every rebuild is what this cache exists
/// to avoid.
@immutable
class ProofSourceRevision {
  const ProofSourceRevision({
    required this.entryId,
    required this.archiveScope,
    required this.ownerScope,
    required this.transcriptRevision,
    required this.transcriptFingerprint,
    required this.transcriptLength,
    required this.sourceType,
    required this.createdAt,
    required this.deleted,
    required this.archived,
    required this.allowedByArchivePolicy,
    required this.remoteProcessingConsented,
  });

  final String entryId;
  final String archiveScope;
  final String ownerScope;
  final String transcriptRevision;
  final String transcriptFingerprint;
  final int transcriptLength;
  final ProofSourceType sourceType;
  final DateTime createdAt;
  final bool deleted;
  final bool archived;
  final bool allowedByArchivePolicy;
  final bool remoteProcessingConsented;
}

/// Memoization for the proof-admission pipeline.
///
/// The pipeline is deliberately paranoid: a stored proof is re-verified against
/// the archive as it exists *now* every time it is about to be rendered, and
/// that re-verification hashes the transcript behind every citation. Correct,
/// but on a rebuild-heavy surface it means hashing the whole archive again to
/// obtain answers that almost never changed.
///
/// This layer removes the repeated hashing without softening the check:
///
/// * Every key is built from ids, digests and version integers. No transcript,
///   quote or statement is ever part of a key.
/// * A hit additionally requires that the transcript and every structural fact
///   behind it still compare equal, so the only thing a hit can save is the
///   hashing itself. A changed transcript, revision, scope, flag, config
///   version or scorer version all miss. A false hit would let a stale proof
///   render, which is the single failure this pipeline exists to prevent, so
///   correctness is chosen over speed at every branch.
/// * Both caches are bounded at [maximumCachedEntries] and evict least recently
///   used, because an unbounded cache over user content is a memory and a
///   privacy problem rather than an optimisation.
class ProofAdmissionCache {
  ProofAdmissionCache({
    int maximumEntries = maximumCachedEntries,
    ProofTranscriptDigest transcriptFingerprint = _sha256Hex,
    ProofTranscriptDigest transcriptRevision = UserContentSafety.privacyHash,
    ProofPipelineTimings? timings,
  }) : _revisions = _LruMap<String, _RevisionRecord>(maximumEntries),
       _features = _LruMap<String, _FeatureRecord>(maximumEntries),
       // The digests are private fields so nothing can swap them after
       // construction, and a private field cannot be named as an initializing
       // formal, so the analyzer's suggestion does not apply here.
       // ignore: prefer_initializing_formals
       _transcriptFingerprint = transcriptFingerprint,
       // ignore: prefer_initializing_formals
       _transcriptRevision = transcriptRevision,
       timings = timings ?? ProofPipelineTimings();

  /// The bound on each cache. Reached in a large archive, so eviction is a
  /// normal operating condition rather than an error path.
  static const int maximumCachedEntries = 128;

  /// Bumped whenever the meaning of a cached value changes, so an old entry can
  /// never be read back under a new interpretation.
  static const int keySchemaVersion = 1;

  final _LruMap<String, _RevisionRecord> _revisions;
  final _LruMap<String, _FeatureRecord> _features;
  final ProofTranscriptDigest _transcriptFingerprint;
  final ProofTranscriptDigest _transcriptRevision;

  /// Phase durations for this pipeline run, readable as bands only.
  final ProofPipelineTimings timings;

  int _hitCount = 0;
  int _missCount = 0;

  /// Diagnostics. Counts only, so they can be logged anywhere.
  int get hitCount => _hitCount;

  int get missCount => _missCount;

  /// Key for the source revision index.
  ///
  /// The archive and owner scope are part of the key rather than checked
  /// afterwards, so one archive's revisions can never be read for another even
  /// when both hold an entry with the same id.
  static String revisionKey({
    required String archiveScope,
    required String ownerScope,
    required String entryId,
  }) => 'rev|v$keySchemaVersion|$archiveScope|$ownerScope|$entryId';

  /// Key for the candidate feature-vector cache.
  ///
  /// Structural inputs only: the evidence fingerprint identifies which evidence
  /// the vector was built from, and the version integers identify the rules it
  /// was built under. Changing any of them yields a different key, which is what
  /// makes invalidation deterministic instead of a matter of timing.
  static String featureVectorKey({
    required String archiveScope,
    required String evidenceFingerprint,
    required int configVersion,
    required int scorerVersion,
    required int verifierVersion,
  }) =>
      'fv|v$keySchemaVersion|$archiveScope|c$configVersion|s$scorerVersion'
      '|e$verifierVersion|$evidenceFingerprint';

  /// The revision facts for [entry], hashing its transcript only when something
  /// about the entry actually changed.
  ///
  /// The declared [ProofSourceEntry.transcriptRevision] is compared as well as
  /// the transcript itself. Either changing is enough to miss: a revision that
  /// moved without the text moving still means the entry was rewritten, and text
  /// that moved without the revision moving is exactly the case a cache must not
  /// paper over.
  ProofSourceRevision revisionFor(ProofSourceEntry entry) {
    final key = revisionKey(
      archiveScope: entry.archiveScope,
      ownerScope: entry.ownerScope,
      entryId: entry.entryId,
    );
    final cached = _revisions.get(key);
    if (cached != null &&
        cached.matches(entry) &&
        cached.revision.transcriptRevision == entry.transcriptRevision) {
      _hitCount += 1;
      return cached.revision;
    }
    _missCount += 1;
    final revision = ProofSourceRevision(
      entryId: entry.entryId,
      archiveScope: entry.archiveScope,
      ownerScope: entry.ownerScope,
      transcriptRevision: entry.transcriptRevision,
      transcriptFingerprint: _transcriptFingerprint(entry.transcript),
      transcriptLength: entry.transcript.length,
      sourceType: entry.sourceType,
      createdAt: entry.createdAt,
      deleted: entry.deleted,
      archived: entry.archived,
      allowedByArchivePolicy: entry.allowedByArchivePolicy,
      remoteProcessingConsented: entry.remoteProcessingConsented,
    );
    _revisions.put(key, _RevisionRecord(entry.transcript, revision));
    return revision;
  }

  /// A [ProofSourceEntry] whose revision was derived from the transcript, built
  /// without re-deriving it when the transcript is unchanged.
  ///
  /// This is the display path's version of the same problem: the revision is a
  /// hash of the transcript, so preparing the archive for revalidation hashes
  /// every entry before the verifier has looked at any of them. The derived
  /// revision uses the same function the capture path used, so an entry that was
  /// edited still reads as a different revision and the proof that quoted the
  /// old text still reads as stale.
  ProofSourceEntry sourceEntryFor({
    required String entryId,
    required String archiveScope,
    required String ownerScope,
    required String transcript,
    required DateTime createdAt,
    required ProofSourceType sourceType,
    bool deleted = false,
    bool archived = false,
    bool allowedByArchivePolicy = true,
    bool remoteProcessingConsented = false,
  }) {
    final key = revisionKey(
      archiveScope: archiveScope,
      ownerScope: ownerScope,
      entryId: entryId,
    );
    final cached = _revisions.get(key);
    // The declared revision is not compared here because there is none to
    // compare: it is a pure function of the transcript, which has just been
    // compared in full.
    final reusable =
        cached != null &&
        cached.sameTranscript(transcript) &&
        cached.sameStructure(
          sourceType: sourceType,
          createdAt: createdAt,
          deleted: deleted,
          archived: archived,
          allowedByArchivePolicy: allowedByArchivePolicy,
          remoteProcessingConsented: remoteProcessingConsented,
        );
    final ProofSourceRevision revision;
    if (reusable) {
      _hitCount += 1;
      revision = cached.revision;
    } else {
      _missCount += 1;
      revision = ProofSourceRevision(
        entryId: entryId,
        archiveScope: archiveScope,
        ownerScope: ownerScope,
        transcriptRevision: _transcriptRevision(transcript),
        transcriptFingerprint: _transcriptFingerprint(transcript),
        transcriptLength: transcript.length,
        sourceType: sourceType,
        createdAt: createdAt,
        deleted: deleted,
        archived: archived,
        allowedByArchivePolicy: allowedByArchivePolicy,
        remoteProcessingConsented: remoteProcessingConsented,
      );
      _revisions.put(key, _RevisionRecord(transcript, revision));
    }
    return ProofSourceEntry(
      entryId: entryId,
      archiveScope: archiveScope,
      ownerScope: ownerScope,
      transcript: transcript,
      transcriptRevision: revision.transcriptRevision,
      createdAt: createdAt,
      sourceType: sourceType,
      deleted: deleted,
      archived: archived,
      allowedByArchivePolicy: allowedByArchivePolicy,
      remoteProcessingConsented: remoteProcessingConsented,
    );
  }

  /// The feature vector for one candidate, computing it at most once per
  /// distinct structural key.
  ///
  /// [sourceEntryIds] is the provenance of the vector: the entries whose
  /// evidence it was built from. It is recorded rather than inferred so
  /// [invalidateEntry] can drop exactly the vectors an edited entry could have
  /// influenced, instead of guessing from a fingerprint that names no entries.
  ProofFeatureVector featureVector({
    required String archiveScope,
    required String evidenceFingerprint,
    required Set<String> sourceEntryIds,
    required ProofFeatureVector Function() compute,
    int configVersion = 1,
    int scorerVersion = 1,
    int verifierVersion = 1,
  }) {
    final key = featureVectorKey(
      archiveScope: archiveScope,
      evidenceFingerprint: evidenceFingerprint,
      configVersion: configVersion,
      scorerVersion: scorerVersion,
      verifierVersion: verifierVersion,
    );
    final cached = _features.get(key);
    if (cached != null) {
      _hitCount += 1;
      return cached.vector;
    }
    _missCount += 1;
    final computed = compute();
    _features.put(
      key,
      _FeatureRecord(
        vector: computed,
        archiveScope: archiveScope,
        sourceEntryIds: Set<String>.unmodifiable(sourceEntryIds),
      ),
    );
    return computed;
  }

  /// Drops everything derived from one entry, in every archive that holds it.
  void invalidateEntry(String entryId) {
    _revisions.removeWhere((_, record) => record.revision.entryId == entryId);
    _features.removeWhere(
      (_, record) => record.sourceEntryIds.contains(entryId),
    );
  }

  /// Drops everything belonging to one archive.
  ///
  /// Called on an archive or account switch. A cache that outlived the switch
  /// would be able to answer for the archive that is no longer open, so the
  /// scope is dropped wholesale rather than re-checked per read.
  void invalidateArchive(String archiveScope) {
    _revisions.removeWhere(
      (_, record) => record.revision.archiveScope == archiveScope,
    );
    _features.removeWhere((_, record) => record.archiveScope == archiveScope);
  }

  /// Drops every cached answer. Phase timings are left alone: they describe the
  /// run, not the archive.
  void invalidateAll() {
    _revisions.clear();
    _features.clear();
  }

  @visibleForTesting
  int get revisionCount => _revisions.length;

  @visibleForTesting
  int get featureVectorCount => _features.length;

  /// Every live key, so a test can assert what a key is allowed to contain.
  @visibleForTesting
  List<String> get debugCacheKeys => [..._revisions.keys, ..._features.keys];

  static String _sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}

/// Stopwatch-based phase measurement for one pipeline run.
///
/// Durations are readable as bands only. A precise timing is a function of the
/// content that produced it — a long verification means a long transcript with
/// many citations — so the raw figure is treated as user data and never leaves
/// this object except to a test.
///
/// The banding is [ProofAdmissionAnalytics.durationBand] rather than a private
/// copy of it, so there is exactly one definition of what "fast" means.
class ProofPipelineTimings {
  ProofPipelineTimings();

  /// The event a phase band is reported under.
  static const String eventName = 'proof_pipeline_phase';

  final Map<ProofPipelinePhase, Duration> _totals =
      <ProofPipelinePhase, Duration>{};

  /// Runs [body], adding its wall time to [phase], and returns its result.
  ///
  /// The duration is recorded even when [body] throws, because a phase that
  /// failed slowly is the one worth knowing about.
  T measure<T>(ProofPipelinePhase phase, T Function() body) {
    final stopwatch = Stopwatch()..start();
    try {
      return body();
    } finally {
      stopwatch.stop();
      record(phase, stopwatch.elapsed);
    }
  }

  /// Adds an already-measured [duration] to [phase].
  ///
  /// Repeated measurement accumulates: a phase that runs once per claim is one
  /// phase that took the sum of its parts, not several unrelated readings.
  void record(ProofPipelinePhase phase, Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(
        duration.inMilliseconds,
        'duration',
        'must not be negative',
      );
    }
    _totals[phase] = (_totals[phase] ?? Duration.zero) + duration;
  }

  /// The phases measured so far, in declaration order so a report is stable.
  List<ProofPipelinePhase> get measuredPhases =>
      ProofPipelinePhase.values.where(_totals.containsKey).toList();

  /// The band for [phase], or null when it was never measured. An unmeasured
  /// phase reports nothing rather than reporting as instant.
  String? bandFor(ProofPipelinePhase phase) {
    final total = _totals[phase];
    return total == null ? null : ProofAdmissionAnalytics.durationBand(total);
  }

  /// Every measured phase as a band.
  Map<ProofPipelinePhase, String> bands() => {
    for (final phase in measuredPhases)
      phase: ProofAdmissionAnalytics.durationBand(_totals[phase]!),
  };

  /// One analytics payload per measured phase.
  ///
  /// A phase is reported as a `stage` token plus a `duration_band`, reusing keys
  /// the privacy guard already allows, so adding a phase never requires widening
  /// the guard's allowlist. Every value is a closed-set token; there is no code
  /// path here that can emit a millisecond figure.
  List<Map<String, Object>> analyticsPayloads() => [
    for (final phase in measuredPhases)
      {
        'stage': phase.token,
        'duration_band': ProofAdmissionAnalytics.durationBand(_totals[phase]!),
      },
  ];

  /// The unbanded total for [phase]. Test-only: a raw timing is content-derived.
  @visibleForTesting
  Duration? rawDurationFor(ProofPipelinePhase phase) => _totals[phase];

  void reset() => _totals.clear();
}

/// One entry of the source revision index.
class _RevisionRecord {
  _RevisionRecord(this._transcript, this.revision);

  /// Held only so an unchanged transcript can be recognised without hashing it
  /// again. It is never exposed, never persisted, never part of a key, and it is
  /// dropped by eviction or by any of the invalidation calls. Comparison is by
  /// identity first and content second — never by a cheap proxy such as length
  /// alone, which two different transcripts can share.
  final String _transcript;

  final ProofSourceRevision revision;

  bool sameTranscript(String transcript) =>
      identical(_transcript, transcript) ||
      (_transcript.length == transcript.length && _transcript == transcript);

  bool sameStructure({
    required ProofSourceType sourceType,
    required DateTime createdAt,
    required bool deleted,
    required bool archived,
    required bool allowedByArchivePolicy,
    required bool remoteProcessingConsented,
  }) =>
      revision.sourceType == sourceType &&
      revision.createdAt == createdAt &&
      revision.deleted == deleted &&
      revision.archived == archived &&
      revision.allowedByArchivePolicy == allowedByArchivePolicy &&
      revision.remoteProcessingConsented == remoteProcessingConsented;

  bool matches(ProofSourceEntry entry) =>
      sameTranscript(entry.transcript) &&
      sameStructure(
        sourceType: entry.sourceType,
        createdAt: entry.createdAt,
        deleted: entry.deleted,
        archived: entry.archived,
        allowedByArchivePolicy: entry.allowedByArchivePolicy,
        remoteProcessingConsented: entry.remoteProcessingConsented,
      );
}

/// One entry of the feature-vector cache, with the provenance needed to drop it.
class _FeatureRecord {
  _FeatureRecord({
    required this.vector,
    required this.archiveScope,
    required this.sourceEntryIds,
  });

  final ProofFeatureVector vector;
  final String archiveScope;
  final Set<String> sourceEntryIds;
}

/// A least-recently-used map with a hard bound.
///
/// Backed by a [LinkedHashMap], so ordering is insertion/recency order rather
/// than hash order: which key is evicted at the bound is the same on every run
/// and on every platform.
class _LruMap<K, V extends Object> {
  _LruMap(this.maximumSize) {
    if (maximumSize <= 0) {
      throw ArgumentError.value(
        maximumSize,
        'maximumSize',
        'must be greater than zero',
      );
    }
  }

  final int maximumSize;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  int get length => _entries.length;

  Iterable<K> get keys => _entries.keys;

  /// Reads [key] and marks it most recently used.
  V? get(K key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  /// Writes [key] as most recently used, evicting from the least recently used
  /// end until the bound holds.
  void put(K key, V value) {
    _entries
      ..remove(key)
      ..[key] = value;
    while (_entries.length > maximumSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  void removeWhere(bool Function(K key, V value) test) =>
      _entries.removeWhere(test);

  void clear() => _entries.clear();
}
