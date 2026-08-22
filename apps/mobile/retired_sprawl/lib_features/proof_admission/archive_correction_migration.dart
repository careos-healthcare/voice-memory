import 'dart:convert';

import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:crypto/crypto.dart';

/// Legacy feedback systems that predate the canonical [ArchiveCorrection].
///
/// Every migrated correction names its origin system in
/// [ArchiveCorrection.sourceSurface] so a stored correction can always be
/// traced back to the legacy surface that produced it.
enum LegacyFeedbackSystem {
  /// `ArchiveFeedback` and the `archive_insight_feedback` prefs blob:
  /// `useful` / `tooGeneric` / `notMe` / `feelsRight` / `notQuite` / hidden ids.
  archiveFeedback('legacy_archive_feedback'),

  /// Post-save and early-archive insight feedback:
  /// `fits` / `notQuite` / `tooEarly` / `saveAsWatchTheme`.
  insightFeedback('legacy_insight_feedback'),

  /// Proof quality response feedback:
  /// `useful` / `tooVague` / `notRelevant`.
  proofQuality('legacy_proof_quality'),

  /// Post-save signal feedback:
  /// `anotherAngle` / `notRelated` / `notUseful` / `watchLightly`.
  signalFeedback('legacy_signal_feedback');

  const LegacyFeedbackSystem(this.sourceSurface);

  /// Value written to [ArchiveCorrection.sourceSurface].
  final String sourceSurface;
}

/// Structural values supplied by the caller while migrating legacy JSON.
///
/// Legacy feedback did not carry all canonical correction fields, so migration
/// is only possible when the caller can safely identify the archive and proof.
/// The seed carries structural identifiers only — it has no field for legacy
/// free text, and the migration never reads text out of the legacy record.
class ArchiveCorrectionMigrationSeed {
  const ArchiveCorrectionMigrationSeed({
    required this.archiveScope,
    required this.targetProofId,
    required this.targetProofFingerprint,
    required this.semanticFramingFingerprint,
    required this.wordingFingerprint,
    required this.affectedEvidenceRefs,
    required this.createdAt,
    this.legacyRecordId,
  });

  final String archiveScope;
  final String targetProofId;
  final String targetProofFingerprint;
  final String semanticFramingFingerprint;
  final String wordingFingerprint;
  final List<String> affectedEvidenceRefs;
  final DateTime createdAt;

  /// Identity of the legacy row when it is not carried inside the legacy JSON.
  ///
  /// Used only to derive a stable correction id; never stored as content.
  final String? legacyRecordId;
}

/// One legacy row queued for migration.
class LegacyFeedbackRecord {
  const LegacyFeedbackRecord({
    required this.system,
    required this.json,
    required this.seed,
  });

  final LegacyFeedbackSystem system;
  final Map<String, dynamic> json;
  final ArchiveCorrectionMigrationSeed seed;
}

/// Explicit, versioned, idempotent migration from legacy feedback systems into
/// the canonical [ArchiveCorrection] model.
///
/// The migration is pure: it reads legacy JSON and returns a correction (or
/// null). It never deletes, rewrites, or otherwise mutates legacy data, so the
/// legacy records stay available for audit and rollback.
///
/// ## Mapping table (migration version [migrationVersion])
///
/// | legacy value | canonical choice | qualifier |
/// | --- | --- | --- |
/// | `accurate`, `fits`, `feelsRight`, `useful` | `exactlyRight` | — |
/// | `wrongAngle`, `anotherAngle` | `wrong`, or `wrongWording` when the record
///   proves the rejection was wording-only (see [_wordingOnlyDowngrade]) | — |
/// | `tooGeneric`, `tooVague` | `wrongWording` | `scopeTooBroad` |
/// | `notQuite` | `partlyRight`, or `wrong` on stronger rejection evidence
///   (see [_strongerRejectionUpgrade]) | — |
/// | `tooEarly` | `partlyRight` | `tooEarly` |
/// | `hide`, `hidden`, `hide this` | `wrong` (artifact-scoped) | — |
/// | `notRelated`, `wrongThread`, `notRelevant` | `wrongEvidence` | — |
/// | `notMe` | `wrong` | — |
/// | `notUseful` | `partlyRight` | — |
/// | `saveAsWatchTheme`, `background`, `watchLightly` | none (null) | — |
///
/// Unrecognised legacy values return null rather than being guessed at.
///
/// Legacy `hide` is an artifact-scoped suppression, so it maps to `wrong` for
/// that one artifact. Migration can never produce
/// [ArchiveCorrectionChoice.ignoreForever]: the table is typed with
/// [_MigratableChoice], which has no archive-wide ignore value, so an
/// archive-wide ignore cannot be created without an explicit user action.
abstract final class ArchiveCorrectionMigration {
  ArchiveCorrectionMigration._();

  /// Version of the mapping table below.
  ///
  /// Version 1 was the ad-hoc per-surface mapping that preceded this table.
  static const migrationVersion = 2;

  /// How many recorded legacy push-backs on the same artifact count as
  /// stronger rejection evidence for `notQuite`.
  static const strongerRejectionRepeatThreshold = 2;

  /// Migrates a legacy row from any known [LegacyFeedbackSystem].
  ///
  /// Returns null when the legacy value is a deferral signal or is not
  /// recognised.
  static ArchiveCorrection? migrate({
    required LegacyFeedbackSystem system,
    required Map<String, dynamic> json,
    required ArchiveCorrectionMigrationSeed seed,
  }) {
    final value = _legacyValue(system, json);
    if (value.isEmpty || _deferralSignals.contains(value)) return null;
    final row = _table[value];
    if (row == null) return null;
    final choice = row.refine?.call(json) ?? row.choice;
    return _build(
      system: system,
      seed: seed,
      json: json,
      choice: choice.canonical,
      qualifier: row.qualifier,
    );
  }

  /// Migrates the `archive_insight_feedback` family of legacy rows.
  static ArchiveCorrection? fromArchiveFeedbackJson(
    Map<String, dynamic> json, {
    required ArchiveCorrectionMigrationSeed seed,
  }) => migrate(
    system: LegacyFeedbackSystem.archiveFeedback,
    json: json,
    seed: seed,
  );

  /// Migrates the JSON representation of `InsightFeedbackChoice`.
  ///
  /// `saveAsWatchTheme` returns null because it is a curation action, not a
  /// statement about proof correctness.
  static ArchiveCorrection? fromInsightFeedbackJson(
    Map<String, dynamic> json, {
    required ArchiveCorrectionMigrationSeed seed,
  }) => migrate(
    system: LegacyFeedbackSystem.insightFeedback,
    json: json,
    seed: seed,
  );

  /// Migrates active proof-quality feedback JSON where it has correction
  /// semantics. Unknown states and non-correction states return null.
  static ArchiveCorrection? fromProofQualityJson(
    Map<String, dynamic> json, {
    required ArchiveCorrectionMigrationSeed seed,
  }) => migrate(
    system: LegacyFeedbackSystem.proofQuality,
    json: json,
    seed: seed,
  );

  /// Migrates post-save signal feedback JSON.
  static ArchiveCorrection? fromSignalFeedbackJson(
    Map<String, dynamic> json, {
    required ArchiveCorrectionMigrationSeed seed,
  }) => migrate(
    system: LegacyFeedbackSystem.signalFeedback,
    json: json,
    seed: seed,
  );

  /// Migrates a batch, skipping rows that are already represented in
  /// [existingCorrections] or earlier in the same batch.
  static List<ArchiveCorrection> migrateAll(
    Iterable<LegacyFeedbackRecord> records, {
    Iterable<ArchiveCorrection> existingCorrections = const [],
  }) {
    final seen = existingCorrections
        .map((correction) => correction.correctionId)
        .toSet();
    final migrated = <ArchiveCorrection>[];
    for (final record in records) {
      final correction = migrate(
        system: record.system,
        json: record.json,
        seed: record.seed,
      );
      if (correction == null) continue;
      if (!seen.add(correction.correctionId)) continue;
      migrated.add(correction);
    }
    return migrated;
  }

  /// Deterministic correction id for a legacy row.
  ///
  /// Derived from the source system plus the legacy record identity, so
  /// migrating the same row twice yields the same id and callers can dedupe.
  /// [migrationVersion] is deliberately excluded: a later table version must
  /// still recognise rows migrated by an earlier one.
  static String correctionIdFor({
    required LegacyFeedbackSystem system,
    required Map<String, dynamic> json,
    required ArchiveCorrectionMigrationSeed seed,
  }) => _digest(
    'archive_correction_migration|${system.sourceSurface}'
    '|${seed.archiveScope}|${seed.targetProofId}'
    '|${_legacyRecordIdentity(system, json, seed)}',
  );

  /// Whether a legacy row has already been migrated into
  /// [existingCorrections].
  static bool isAlreadyMigrated({
    required Iterable<ArchiveCorrection> existingCorrections,
    required LegacyFeedbackSystem system,
    required Map<String, dynamic> json,
    required ArchiveCorrectionMigrationSeed seed,
  }) {
    final id = correctionIdFor(system: system, json: json, seed: seed);
    return existingCorrections.any(
      (correction) => correction.correctionId == id,
    );
  }

  /// Whether [legacyValue] is a deferral or save signal, which is deliberately
  /// not a correction at all.
  static bool isDeferralSignal(String legacyValue) =>
      _deferralSignals.contains(_normalise(legacyValue));

  /// Whether [legacyValue] appears anywhere in the migration table, either as a
  /// correction or as a known deferral signal.
  static bool recognisesLegacyValue(String legacyValue) {
    final value = _normalise(legacyValue);
    return _table.containsKey(value) || _deferralSignals.contains(value);
  }

  static ArchiveCorrection _build({
    required LegacyFeedbackSystem system,
    required ArchiveCorrectionMigrationSeed seed,
    required Map<String, dynamic> json,
    required ArchiveCorrectionChoice choice,
    required ArchiveCorrectionQualifier? qualifier,
  }) {
    final createdAt = _legacyTimestamp(json) ?? seed.createdAt;
    return ArchiveCorrection(
      correctionId: correctionIdFor(system: system, json: json, seed: seed),
      archiveScope: seed.archiveScope,
      targetProofId: seed.targetProofId,
      targetProofFingerprint: seed.targetProofFingerprint,
      semanticFramingFingerprint: seed.semanticFramingFingerprint,
      wordingFingerprint: seed.wordingFingerprint,
      affectedEvidenceRefs: seed.affectedEvidenceRefs,
      choice: choice,
      qualifier: qualifier,
      createdAt: createdAt,
      updatedAt: createdAt,
      sourceSurface: system.sourceSurface,
    );
  }

  /// Reads the legacy choice out of the field names each system used.
  static String _legacyValue(
    LegacyFeedbackSystem system,
    Map<String, dynamic> json,
  ) {
    final raw = switch (system) {
      LegacyFeedbackSystem.archiveFeedback =>
        json['type'] ?? json['feedbackType'] ?? json['choice'],
      LegacyFeedbackSystem.insightFeedback =>
        json['choice'] ?? json['feedback'],
      LegacyFeedbackSystem.proofQuality =>
        json['feedbackState'] ?? json['feedback'] ?? json['choice'],
      LegacyFeedbackSystem.signalFeedback => json['action'] ?? json['choice'],
    };
    return _normalise(raw);
  }

  /// Identity of the legacy row, used only to derive a stable correction id.
  static String _legacyRecordIdentity(
    LegacyFeedbackSystem system,
    Map<String, dynamic> json,
    ArchiveCorrectionMigrationSeed seed,
  ) {
    for (final candidate in [
      json['id'],
      json['feedbackId'],
      json['recordId'],
      json['legacyId'],
      seed.legacyRecordId,
    ]) {
      if (candidate is String && candidate.isNotEmpty) return candidate;
    }
    // Legacy blobs that stored one row per proof carry no row id, so the
    // migrated value keeps the record distinguishable within the proof.
    return 'value:${_legacyValue(system, json)}';
  }

  static DateTime? _legacyTimestamp(Map<String, dynamic> json) {
    final raw = json['createdAt'] ?? json['answeredAt'] ?? json['recordedAt'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static String _normalise(Object? raw) => raw is String
      ? raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')
      : '';

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}

/// Canonical choices a migration is allowed to produce.
///
/// [ArchiveCorrectionChoice.ignoreForever] is intentionally absent: an
/// archive-wide ignore is never inferred from legacy data.
enum _MigratableChoice {
  exactlyRight,
  partlyRight,
  wrong,
  wrongWording,
  wrongEvidence;

  ArchiveCorrectionChoice get canonical => switch (this) {
    _MigratableChoice.exactlyRight => ArchiveCorrectionChoice.exactlyRight,
    _MigratableChoice.partlyRight => ArchiveCorrectionChoice.partlyRight,
    _MigratableChoice.wrong => ArchiveCorrectionChoice.wrong,
    _MigratableChoice.wrongWording => ArchiveCorrectionChoice.wrongWording,
    _MigratableChoice.wrongEvidence => ArchiveCorrectionChoice.wrongEvidence,
  };
}

class _MigrationRow {
  const _MigrationRow(this.choice, {this.qualifier, this.refine});

  final _MigratableChoice choice;
  final ArchiveCorrectionQualifier? qualifier;

  /// Narrows [choice] using closed-set structural evidence on the legacy row.
  final _MigratableChoice? Function(Map<String, dynamic> json)? refine;
}

/// The migration table, keyed by normalised legacy value (lower-cased, with
/// separators removed, so `too_vague`, `tooVague`, and `Too Vague` all match).
const Map<String, _MigrationRow> _table = {
  // Row 1 — legacy_archive_feedback, legacy_insight_feedback,
  // legacy_proof_quality: the user confirmed the proof as stated.
  'accurate': _MigrationRow(_MigratableChoice.exactlyRight),
  'fits': _MigrationRow(_MigratableChoice.exactlyRight),
  'feelsright': _MigrationRow(_MigratableChoice.exactlyRight),
  'useful': _MigrationRow(_MigratableChoice.exactlyRight),

  // Row 2 — legacy_archive_feedback, legacy_signal_feedback: the framing was
  // rejected. Downgraded to wrongWording only on wording-only evidence.
  'wrongangle': _MigrationRow(
    _MigratableChoice.wrong,
    refine: _wordingOnlyDowngrade,
  ),
  'anotherangle': _MigrationRow(
    _MigratableChoice.wrong,
    refine: _wordingOnlyDowngrade,
  ),

  // Row 3 — legacy_archive_feedback, legacy_proof_quality: the statement was
  // true but too broad to be useful.
  'toogeneric': _MigrationRow(
    _MigratableChoice.wrongWording,
    qualifier: ArchiveCorrectionQualifier.scopeTooBroad,
  ),
  'toovague': _MigrationRow(
    _MigratableChoice.wrongWording,
    qualifier: ArchiveCorrectionQualifier.scopeTooBroad,
  ),

  // Row 4 — legacy_insight_feedback, legacy_archive_feedback: a soft
  // push-back, escalated only on stronger rejection evidence.
  'notquite': _MigrationRow(
    _MigratableChoice.partlyRight,
    refine: _strongerRejectionUpgrade,
  ),

  // Row 5 — legacy_insight_feedback: right idea, wrong moment.
  'tooearly': _MigrationRow(
    _MigratableChoice.partlyRight,
    qualifier: ArchiveCorrectionQualifier.tooEarly,
  ),

  // Row 6 — legacy_archive_feedback: legacy "Hide" suppressed the exact
  // artifact only, so it stays artifact-scoped as `wrong`. It must never
  // become an archive-wide ignore.
  'hide': _MigrationRow(_MigratableChoice.wrong),
  'hidden': _MigrationRow(_MigratableChoice.wrong),
  'hidethis': _MigrationRow(_MigratableChoice.wrong),

  // Row 7 — legacy_signal_feedback, legacy_proof_quality: the cited linkage is
  // wrong, not the statement, so this is a relationship correction.
  'notrelated': _MigrationRow(_MigratableChoice.wrongEvidence),
  'wrongthread': _MigrationRow(_MigratableChoice.wrongEvidence),
  'notrelevant': _MigrationRow(_MigratableChoice.wrongEvidence),

  // Row 8 — legacy_archive_feedback: the proof is not about this person.
  'notme': _MigrationRow(_MigratableChoice.wrong),

  // Row 9 — legacy_signal_feedback: accurate enough, but it did not land.
  'notuseful': _MigrationRow(_MigratableChoice.partlyRight),

  // Row 10 (deferral signals) lives in [_deferralSignals] and returns null.
};

/// Legacy values that are deferral or save actions rather than rejections.
///
/// These are recognised so they are provably skipped instead of being guessed
/// into a correction.
const Set<String> _deferralSignals = {
  'saveaswatchtheme',
  'background',
  'watchlightly',
};

/// Detects that a legacy `wrongAngle` / `anotherAngle` rejection was about
/// phrasing only, using closed-set structural markers on the legacy row:
///
/// * `wordingOnly: true` — the legacy surface recorded a phrasing-only reject.
/// * `rejectionScope: 'wording'` / `'wording_only'` — the scope the legacy row
///   itself stored for the rejection.
/// * `reason: 'wrongWording'` — legacy `PatternCorrectionReason.wrongWording`.
/// * `correctionAction: 'renamePattern'` / `'rewordOnly'` — legacy
///   `PatternCorrectionAction.renamePattern` relabelled the artifact and left
///   its claim and evidence linkage intact.
///
/// Legacy free text is never inspected; absent an explicit marker the
/// rejection stays a full `wrong` so nothing is silently softened.
_MigratableChoice? _wordingOnlyDowngrade(Map<String, dynamic> json) {
  if (json['wordingOnly'] == true) return _MigratableChoice.wrongWording;
  const wordingScopes = {'wording', 'wordingonly'};
  final scope = ArchiveCorrectionMigration._normalise(json['rejectionScope']);
  if (wordingScopes.contains(scope)) return _MigratableChoice.wrongWording;
  final reason = ArchiveCorrectionMigration._normalise(json['reason']);
  if (reason == 'wrongwording' || reason == 'wording') {
    return _MigratableChoice.wrongWording;
  }
  const wordingActions = {'renamepattern', 'rewordonly'};
  final action = ArchiveCorrectionMigration._normalise(
    json['correctionAction'],
  );
  if (wordingActions.contains(action)) return _MigratableChoice.wrongWording;
  return null;
}

/// Detects that a legacy `notQuite` carried stronger rejection evidence, using
/// closed-set structural markers on the legacy row:
///
/// * `hidden` / `rejected` / `dismissed` set to true — the user removed the
///   artifact after the soft push-back.
/// * `escalatedTo` / `followUpChoice` in `notMe`, `wrongAngle`, `hide`,
///   `hidden` — the legacy surface recorded a harder follow-up answer.
/// * `notQuiteCount` / `rejectionCount` / `negativeCount` at or above
///   [ArchiveCorrectionMigration.strongerRejectionRepeatThreshold] — the same
///   artifact was pushed back on repeatedly.
_MigratableChoice? _strongerRejectionUpgrade(Map<String, dynamic> json) {
  if (json['hidden'] == true ||
      json['rejected'] == true ||
      json['dismissed'] == true) {
    return _MigratableChoice.wrong;
  }
  const escalations = {'notme', 'wrongangle', 'hide', 'hidden'};
  for (final key in ['escalatedTo', 'followUpChoice']) {
    final value = ArchiveCorrectionMigration._normalise(json[key]);
    if (escalations.contains(value)) return _MigratableChoice.wrong;
  }
  for (final key in ['notQuiteCount', 'rejectionCount', 'negativeCount']) {
    final value = json[key];
    if (value is num &&
        value >= ArchiveCorrectionMigration.strongerRejectionRepeatThreshold) {
      return _MigratableChoice.wrong;
    }
  }
  return null;
}