import 'dart:convert';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_consent_boundary.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_migration.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:crypto/crypto.dart';

/// Durable structural correction memory. It deliberately has no API for
/// plaintext notes, provider text, evidence quotes, or transcript content.
class ArchiveCorrectionStore implements ProofCorrectionAdmissionPolicy {
  ArchiveCorrectionStore._();

  static final ArchiveCorrectionStore instance = ArchiveCorrectionStore._();
  static const prefsKey = 'canonical_archive_corrections_v1';
  static const defaultArchiveScope = 'local_archive_v1';

  final List<ArchiveCorrection> _records = [];
  bool _loaded = false;
  MobilePrefsStore? _prefs;
  String _activeArchiveScope = defaultArchiveScope;

  List<ArchiveCorrection> get records => List.unmodifiable(_records);

  String get activeArchiveScope => _activeArchiveScope;

  void configure(MobilePrefsStore prefs) {
    _prefs = prefs;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final raw = await _prefs?.readJsonMap(prefsKey);
    final rows = raw?['records'];
    _records
      ..clear()
      ..addAll(
        rows is List
            ? rows.whereType<Map>().map(
                (row) =>
                    ArchiveCorrection.fromJson(Map<String, dynamic>.from(row)),
              )
            : const <ArchiveCorrection>[],
      );
    _loaded = true;
  }

  Future<ArchiveCorrection> recordForProof({
    required VerifiedProof proof,
    required ArchiveCorrectionChoice choice,
    required String sourceSurface,
    ArchiveCorrectionQualifier? qualifier,
    List<String> disputedEvidenceRefs = const [],
    String? preferredWording,
    DateTime? now,
  }) async {
    await ensureLoaded();
    final timestamp = (now ?? DateTime.now()).toUtc();
    for (var index = 0; index < _records.length; index++) {
      final existing = _records[index];
      // Ignore forever is deliberately not supersedable here. Reversing it is an
      // explicit archive-control action ([undoIgnoreForever]), so it cannot be
      // undone by tapping a positive choice on a later card.
      if (!existing.superseded &&
          existing.choice != ArchiveCorrectionChoice.ignoreForever &&
          existing.archiveScope == proof.archiveScope &&
          existing.targetProofId == proof.proofId) {
        _records[index] = existing.copyWith(
          superseded: true,
          updatedAt: timestamp,
        );
      }
    }
    final correction = ArchiveCorrection(
      correctionId: _digest(
        '${proof.archiveScope}|${proof.proofId}|${timestamp.toIso8601String()}',
      ),
      archiveScope: proof.archiveScope,
      targetProofId: proof.proofId,
      targetProofFingerprint: proof.proofFingerprint,
      semanticFramingFingerprint: proof.semanticFramingFingerprint,
      wordingFingerprint: proof.wordingFingerprint,
      affectedEvidenceRefs:
          proof.claims
              .expand((claim) => claim.evidence)
              .map((item) => item.sourceEntryId)
              .toSet()
              .toList()
            ..sort(),
      disputedEvidenceRefs: List<String>.of(disputedEvidenceRefs)..sort(),
      preferredWording: preferredWording,
      choice: choice,
      qualifier: qualifier,
      createdAt: timestamp,
      updatedAt: timestamp,
      sourceSurface: sourceSurface,
    );
    _records.add(correction);
    await _persist();
    await BetaAnalyticsHooks.patternReviewed(
      reviewOutcome: BetaAnalyticsConsentBoundary.reviewOutcomeFor(choice),
    );
    return correction;
  }

  /// Compatibility migration for legacy structural feedback. Plaintext legacy
  /// correction notes are intentionally not copied into this store.
  ///
  /// The mapping itself lives in [ArchiveCorrectionMigration] rather than here,
  /// so there is one reviewable table rather than a second inline mapping that
  /// could drift away from it. In particular the table cannot express
  /// `ignoreForever` at all, which is what guarantees a legacy Hide never
  /// becomes archive-wide suppression.
  Future<void> migrateLegacyArchiveFeedback() async {
    await ensureLoaded();
    final legacy = await _prefs?.readJsonMap('archive_insight_feedback');
    if (legacy == null || legacy.isEmpty) return;
    final hidden = (legacy['hidden'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    final feelsRight = legacy['feelsRight'];
    final notQuite = legacy['notQuite'];
    final ids = <String>{
      ...hidden,
      if (feelsRight is Map) ...feelsRight.keys.map((item) => '$item'),
      if (notQuite is Map) ...notQuite.keys.map((item) => '$item'),
    };

    // Skipping by target proof id, not by correction id, so rows migrated by
    // the earlier inline mapping are recognised and not duplicated.
    final alreadyMigrated = _records
        .where(
          (item) =>
              item.sourceSurface ==
              LegacyFeedbackSystem.archiveFeedback.sourceSurface,
        )
        .map((item) => item.targetProofId)
        .toSet();

    final timestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final pending = <LegacyFeedbackRecord>[];
    for (final id in ids.where((item) => !alreadyMigrated.contains(item))) {
      final negativeCount = notQuite is Map && notQuite[id] is num
          ? (notQuite[id] as num).toInt()
          : 0;
      pending.add(
        LegacyFeedbackRecord(
          system: LegacyFeedbackSystem.archiveFeedback,
          json: {
            'type': hidden.contains(id)
                ? 'hidden'
                : negativeCount > 0
                ? 'notQuite'
                : 'feelsRight',
            'notQuiteCount': negativeCount,
          },
          seed: ArchiveCorrectionMigrationSeed(
            archiveScope: defaultArchiveScope,
            targetProofId: id,
            targetProofFingerprint: _digest('legacy-proof|$id'),
            semanticFramingFingerprint: _digest('legacy-semantic|$id'),
            wordingFingerprint: _digest('legacy-wording|$id'),
            affectedEvidenceRefs: const [],
            createdAt: timestamp,
            legacyRecordId: id,
          ),
        ),
      );
    }
    if (pending.isEmpty) return;

    _records.addAll(
      ArchiveCorrectionMigration.migrateAll(
        pending,
        existingCorrections: _records,
      ),
    );
    await _persist();
  }

  /// Applies the six correction choices to one candidate.
  ///
  /// Ignore forever always wins, including over later positive feedback, and
  /// nothing here can admit a proof the evidence verifier already refused —
  /// this only ever narrows what may surface.
  @override
  ProofCorrectionDecision decide(ProofCorrectionQuery query) {
    final scoped = _records.where(
      (item) => !item.superseded && item.archiveScope == query.archiveScope,
    );
    final matching = scoped
        .where(
          (item) =>
              item.targetProofFingerprint == query.proofFingerprint ||
              item.semanticFramingFingerprint ==
                  query.semanticFramingFingerprint ||
              item.wordingFingerprint == query.wordingFingerprint,
        )
        .toList();
    if (matching.isEmpty) return ProofCorrectionDecision.none;

    for (final item in matching) {
      if (item.choice == ArchiveCorrectionChoice.ignoreForever &&
          _framingMatches(item, query)) {
        return const ProofCorrectionDecision(
          suppressed: true,
          suppressionReason: 'ignore_forever',
        );
      }
    }

    for (final item in matching) {
      if (item.choice == ArchiveCorrectionChoice.wrong &&
          _framingMatches(item, query) &&
          !_hasMateriallyNewEvidence(item, query)) {
        return const ProofCorrectionDecision(
          suppressed: true,
          suppressionReason: 'framing_rejected_as_wrong',
        );
      }
    }

    final disallowed = <String>{};
    for (final item in matching) {
      if (item.choice == ArchiveCorrectionChoice.wrongEvidence &&
          _framingMatches(item, query)) {
        disallowed.addAll(
          item.disputedEvidenceRefs.isEmpty
              ? item.affectedEvidenceRefs
              : item.disputedEvidenceRefs,
        );
      }
    }

    // Wording corrections are keyed on wording, not framing: they are about the
    // sentence the customer rejected, which is what distinguishes them from the
    // branches above. A correction may still reach this candidate through its
    // framing, so both are eligible — but the label the customer chose for this
    // exact sentence is the better answer, and among equally good matches the
    // most recent one is. Picking by list order instead would make the label
    // depend on the order corrections happen to have been stored in.
    final wordingCorrections =
        matching
            .where(
              (item) => item.choice == ArchiveCorrectionChoice.wrongWording,
            )
            .toList()
          ..sort((a, b) {
            final aExact = a.wordingFingerprint == query.wordingFingerprint;
            final bExact = b.wordingFingerprint == query.wordingFingerprint;
            if (aExact != bExact) return aExact ? -1 : 1;
            final byRecency = b.updatedAt.compareTo(a.updatedAt);
            if (byRecency != 0) return byRecency;
            return a.correctionId.compareTo(b.correctionId);
          });

    String? preferredWording;
    for (final item in wordingCorrections) {
      if (item.preferredWording != null) {
        preferredWording ??= item.preferredWording;
        continue;
      }
      // A rejected phrasing with no replacement offered can only be withheld.
      // The relationship survives; this exact sentence does not.
      if (item.wordingFingerprint == query.wordingFingerprint) {
        return const ProofCorrectionDecision(
          suppressed: true,
          suppressionReason: 'wording_rejected',
        );
      }
    }

    final partlyRight = matching.any(
      (item) =>
          item.choice == ArchiveCorrectionChoice.partlyRight &&
          _framingMatches(item, query) &&
          !_hasMateriallyNewEvidence(item, query),
    );

    return ProofCorrectionDecision(
      disallowedEvidenceSourceIds: disallowed,
      confidenceCap: partlyRight ? ProofConfidenceBand.medium : null,
      preferredWording: preferredWording,
    );
  }

  static bool _framingMatches(
    ArchiveCorrection correction,
    ProofCorrectionQuery query,
  ) =>
      correction.semanticFramingFingerprint ==
          query.semanticFramingFingerprint ||
      correction.targetProofFingerprint == query.proofFingerprint;

  /// Structural definition only. Time passing is never materially new evidence:
  /// the candidate has to rest on a source the rejected version did not use.
  static bool _hasMateriallyNewEvidence(
    ArchiveCorrection correction,
    ProofCorrectionQuery query,
  ) {
    if (correction.affectedEvidenceRefs.isEmpty) return false;
    final rejected = correction.affectedEvidenceRefs.toSet();
    return query.evidenceSourceIds.any((id) => !rejected.contains(id));
  }

  /// The records that may influence scoring for [archiveScope].
  ///
  /// Scoped exactly as [decide] is. A correction the user made in another
  /// archive, or one they have since reversed, must not quietly move the
  /// confidence of a proof here. A null scope means "any archive", which is
  /// only for callers that have no archive context of their own.
  Iterable<ArchiveCorrection> _active(String? archiveScope) => _records.where(
    (item) =>
        !item.superseded &&
        (archiveScope == null || item.archiveScope == archiveScope),
  );

  @override
  int positiveHistory(
    String semanticFramingFingerprint, {
    String? archiveScope,
  }) => _active(archiveScope)
      .where(
        (item) =>
            item.semanticFramingFingerprint == semanticFramingFingerprint &&
            (item.choice == ArchiveCorrectionChoice.exactlyRight ||
                item.choice == ArchiveCorrectionChoice.partlyRight),
      )
      .length;

  @override
  int negativeHistory(
    String semanticFramingFingerprint, {
    String? archiveScope,
  }) => _active(archiveScope)
      .where(
        (item) =>
            item.semanticFramingFingerprint == semanticFramingFingerprint &&
            (item.choice == ArchiveCorrectionChoice.wrong ||
                item.choice == ArchiveCorrectionChoice.ignoreForever),
      )
      .length;

  @override
  int wordingRejectionHistory(
    String wordingFingerprint, {
    String? archiveScope,
  }) => _active(archiveScope)
      .where(
        (item) =>
            item.wordingFingerprint == wordingFingerprint &&
            item.choice == ArchiveCorrectionChoice.wrongWording,
      )
      .length;

  @override
  int evidenceRejectionHistory(
    String proofFingerprint, {
    String? archiveScope,
  }) => _active(archiveScope)
      .where(
        (item) =>
            item.targetProofFingerprint == proofFingerprint &&
            item.choice == ArchiveCorrectionChoice.wrongEvidence,
      )
      .length;

  /// Switches the archive whose corrections are active.
  ///
  /// The in-memory records are dropped and the loaded flag reset, so no record
  /// belonging to the previous archive can survive an account switch and be
  /// consulted for the next one.
  Future<void> switchArchive(String archiveScope) async {
    if (archiveScope == _activeArchiveScope) return;
    _activeArchiveScope = archiveScope;
    _records.clear();
    _loaded = false;
    await ensureLoaded();
  }

  /// Reverses an "Ignore forever" from the archive's privacy controls.
  ///
  /// The record is superseded rather than deleted so the correction history
  /// stays auditable and exportable.
  Future<int> undoIgnoreForever({
    required String archiveScope,
    required String semanticFramingFingerprint,
    DateTime? now,
  }) async {
    await ensureLoaded();
    final timestamp = (now ?? DateTime.now()).toUtc();
    var reversed = 0;
    for (var index = 0; index < _records.length; index++) {
      final existing = _records[index];
      if (!existing.superseded &&
          existing.choice == ArchiveCorrectionChoice.ignoreForever &&
          existing.archiveScope == archiveScope &&
          existing.semanticFramingFingerprint == semanticFramingFingerprint) {
        _records[index] = existing.copyWith(
          superseded: true,
          updatedAt: timestamp,
        );
        reversed += 1;
      }
    }
    if (reversed > 0) await _persist();
    return reversed;
  }

  /// Removes all canonical correction memory for the local archive.
  ///
  /// Corrections are user data, so a privacy wipe must clear them alongside
  /// journal entries rather than leaving structural feedback behind.
  Future<void> clearAll() async {
    _records.clear();
    _loaded = true;
    await _prefs?.writeJsonMap(prefsKey, {});
  }

  Future<void> _persist() async {
    await _prefs?.writeJsonMap(prefsKey, {
      'schemaVersion': 1,
      'records': _records.map((item) => item.toJson()).toList(),
    });
  }

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static void resetForTest() {
    instance._records.clear();
    instance._loaded = false;
    instance._prefs = null;
    instance._activeArchiveScope = defaultArchiveScope;
  }
}