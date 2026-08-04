import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../storage/mobile_prefs_store.dart';
import 'archive_correction.dart';
import 'proof_admission_models.dart';
import 'proof_admission_service.dart';

/// Durable structural correction memory. It deliberately has no API for
/// plaintext notes, provider text, evidence quotes, or transcript content.
class ArchiveCorrectionStore implements ProofCorrectionAdmissionPolicy {
  ArchiveCorrectionStore._();

  static final ArchiveCorrectionStore instance = ArchiveCorrectionStore._();
  static const prefsKey = 'canonical_archive_corrections_v1';

  final List<ArchiveCorrection> _records = [];
  bool _loaded = false;
  MobilePrefsStore? _prefs;

  List<ArchiveCorrection> get records => List.unmodifiable(_records);

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
    DateTime? now,
  }) async {
    await ensureLoaded();
    final timestamp = (now ?? DateTime.now()).toUtc();
    for (var index = 0; index < _records.length; index++) {
      final existing = _records[index];
      if (!existing.superseded &&
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
      choice: choice,
      qualifier: qualifier,
      createdAt: timestamp,
      updatedAt: timestamp,
      sourceSurface: sourceSurface,
    );
    _records.add(correction);
    await _persist();
    return correction;
  }

  /// Compatibility migration for legacy structural feedback. Plaintext legacy
  /// correction notes are intentionally not copied into this store.
  Future<void> migrateLegacyArchiveFeedback() async {
    await ensureLoaded();
    final legacy = await _prefs?.readJsonMap('archive_insight_feedback');
    if (legacy == null || legacy.isEmpty) return;
    final hidden = (legacy['hidden'] as List<dynamic>? ?? const [])
        .whereType<String>();
    final feelsRight = legacy['feelsRight'];
    final notQuite = legacy['notQuite'];
    final ids = <String>{
      ...hidden,
      if (feelsRight is Map) ...feelsRight.keys.map((item) => '$item'),
      if (notQuite is Map) ...notQuite.keys.map((item) => '$item'),
    };
    final migratedIds = _records
        .where((item) => item.sourceSurface == 'legacy_archive_feedback')
        .map((item) => item.targetProofId)
        .toSet();
    for (final id in ids.where((item) => !migratedIds.contains(item))) {
      final isHidden = hidden.contains(id);
      final negativeCount = notQuite is Map && notQuite[id] is num
          ? (notQuite[id] as num).toInt()
          : 0;
      final choice = isHidden
          ? ArchiveCorrectionChoice.ignoreForever
          : negativeCount > 0
          ? ArchiveCorrectionChoice.partlyRight
          : ArchiveCorrectionChoice.exactlyRight;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      _records.add(
        ArchiveCorrection(
          correctionId: _digest('legacy|$id'),
          archiveScope: 'local_archive_v1',
          targetProofId: id,
          targetProofFingerprint: _digest('legacy-proof|$id'),
          semanticFramingFingerprint: _digest('legacy-semantic|$id'),
          wordingFingerprint: _digest('legacy-wording|$id'),
          affectedEvidenceRefs: const [],
          choice: choice,
          createdAt: timestamp,
          updatedAt: timestamp,
          sourceSurface: 'legacy_archive_feedback',
        ),
      );
    }
    await _persist();
  }

  @override
  bool suppresses({
    required String archiveScope,
    required String proofFingerprint,
    required String semanticFramingFingerprint,
  }) => _records.any(
    (item) =>
        item.archiveScope == archiveScope &&
        item.choice == ArchiveCorrectionChoice.ignoreForever &&
        (item.targetProofFingerprint == proofFingerprint ||
            item.semanticFramingFingerprint == semanticFramingFingerprint),
  );

  @override
  int positiveHistory(String semanticFramingFingerprint) => _records
      .where(
        (item) =>
            item.semanticFramingFingerprint == semanticFramingFingerprint &&
            (item.choice == ArchiveCorrectionChoice.exactlyRight ||
                item.choice == ArchiveCorrectionChoice.partlyRight),
      )
      .length;

  @override
  int negativeHistory(String semanticFramingFingerprint) => _records
      .where(
        (item) =>
            item.semanticFramingFingerprint == semanticFramingFingerprint &&
            (item.choice == ArchiveCorrectionChoice.wrong ||
                item.choice == ArchiveCorrectionChoice.ignoreForever),
      )
      .length;

  @override
  int wordingRejectionHistory(String wordingFingerprint) => _records
      .where(
        (item) =>
            item.wordingFingerprint == wordingFingerprint &&
            item.choice == ArchiveCorrectionChoice.wrongWording,
      )
      .length;

  @override
  int evidenceRejectionHistory(String proofFingerprint) => _records
      .where(
        (item) =>
            item.targetProofFingerprint == proofFingerprint &&
            item.choice == ArchiveCorrectionChoice.wrongEvidence,
      )
      .length;

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
  }
}
