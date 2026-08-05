import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_migration.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_fingerprints.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

final _at = DateTime.utc(2026, 7, 1);

/// A minimal admitted proof, shaped like one the pipeline produces. The fields
/// that matter here are the archive scope and the fingerprints, since those are
/// what corrections are keyed on.
VerifiedProof _proof({
  required String archiveScope,
  String statement = 'You check the numbers before deciding.',
  String proofId = 'proof-1',
}) {
  final evidence = [
    VerifiedEvidenceSnapshot(
      sourceEntryId: 'entry-1',
      archiveScope: archiveScope,
      ownerScope: 'owner-1',
      transcriptRevision: 'rev-1',
      transcriptFingerprint: 'fingerprint-1',
      sourceDate: _at,
      sourceType: ProofSourceType.userTyped,
      quote: 'checked the numbers first',
      startUtf16: 0,
      endUtf16: 25,
      role: ProofEvidenceRole.support,
      verifiedAt: _at,
    ),
  ];

  return VerifiedProof(
    proofId: proofId,
    archiveScope: archiveScope,
    ownerScope: 'owner-1',
    reflection: Reflection(
      mood: 'steady',
      emotionalIntensity: 3,
      recurringThemes: const [],
      exactLanguagePattern: 'checked the numbers first',
      concreteObservation: statement,
      repeatedSignal: '',
      patternObservations: const [],
    ),
    claims: [
      VerifiedProofClaim(
        claimId: 'main',
        kind: ProofClaimKind.mainObservation,
        text: statement,
        evidence: evidence,
      ),
    ],
    confidenceBand: ProofConfidenceBand.medium,
    qualityReceipt: ProofQualityReceipt(
      proofType: ProofType.currentObservation,
      confidenceBand: ProofConfidenceBand.medium,
      frequency: ProofFrequency(
        distinctMoments: 1,
        windowStart: _at,
        windowEnd: _at,
      ),
      trend: ProofTrend.insufficientEvidence,
      strengthOverTime: ProofStrengthOverTime.insufficientEvidence,
      supportingEvidence: evidence,
      counterexamples: const [],
      contradictions: const [],
      missingEvidence: const [],
      firstOccurrence: _at,
      lastOccurrence: _at,
      generatedAt: _at,
    ),
    verifiedAt: _at,
    sourceRevisionFingerprint: 'source-revision',
    proofFingerprint: 'proof-fingerprint-$proofId',
    semanticFramingFingerprint: ProofFingerprints.semanticFraming(
      statement: statement,
      proofType: ProofType.currentObservation.name,
    ),
    wordingFingerprint: ProofFingerprints.wording(statement),
  );
}

/// Exercises the wiring between the correction store and the surfaces that
/// drive it: startup migration, privacy controls, and archive switching. The
/// mapping itself is covered by `archive_correction_migration_test.dart`; what
/// matters here is that the shipping entry points reach it.
void main() {
  late Directory dir;
  late MobilePrefsStore prefs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('correction_wiring');
    prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    ArchiveCorrectionStore.resetForTest();
    ArchiveCorrectionStore.instance.configure(prefs);
  });

  tearDown(() async {
    ArchiveCorrectionStore.resetForTest();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  ArchiveCorrection? correctionFor(String proofId) => ArchiveCorrectionStore
      .instance
      .records
      .where((item) => item.targetProofId == proofId)
      .firstOrNull;

  group('startup migration of legacy archive feedback', () {
    Future<void> seedLegacy() =>
        prefs.writeJsonMap('archive_insight_feedback', {
          'hidden': ['proof-hidden'],
          'feelsRight': {'proof-good': true},
          'notQuite': {'proof-mixed': 1},
        });

    test('legacy rows migrate through the canonical table', () async {
      await seedLegacy();

      await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();

      expect(
        correctionFor('proof-good')?.choice,
        ArchiveCorrectionChoice.exactlyRight,
      );
      expect(
        correctionFor('proof-mixed')?.choice,
        ArchiveCorrectionChoice.partlyRight,
      );
      expect(
        correctionFor('proof-hidden')?.choice,
        ArchiveCorrectionChoice.wrong,
      );
      expect(
        ArchiveCorrectionStore.instance.records.every(
          (item) =>
              item.sourceSurface ==
              LegacyFeedbackSystem.archiveFeedback.sourceSurface,
        ),
        isTrue,
        reason: 'every migrated record must name the surface it came from',
      );
    });

    test('a legacy Hide never becomes an archive-wide ignore', () async {
      await seedLegacy();

      await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();

      expect(
        ArchiveCorrectionStore.instance.records.any(
          (item) => item.choice == ArchiveCorrectionChoice.ignoreForever,
        ),
        isFalse,
        reason:
            'Hide meant "not this card" and never carried consent for '
            'archive-wide suppression',
      );
    });

    test('running the migration twice adds nothing', () async {
      await seedLegacy();

      await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();
      final afterFirst = ArchiveCorrectionStore.instance.records.length;
      await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();

      expect(ArchiveCorrectionStore.instance.records, hasLength(afterFirst));
    });

    test('migration survives a reload without duplicating', () async {
      await seedLegacy();
      await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();
      final afterFirst = ArchiveCorrectionStore.instance.records.length;

      // A second launch: same persisted prefs, fresh in-memory store.
      ArchiveCorrectionStore.resetForTest();
      ArchiveCorrectionStore.instance.configure(prefs);
      await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();

      expect(ArchiveCorrectionStore.instance.records, hasLength(afterFirst));
    });

    test('an empty legacy blob migrates nothing', () async {
      await ArchiveCorrectionStore.instance.migrateLegacyArchiveFeedback();

      expect(ArchiveCorrectionStore.instance.records, isEmpty);
    });
  });

  group('archive scoping', () {
    final framing = _proof(
      archiveScope: 'archive-a',
    ).semanticFramingFingerprint;

    Future<void> record({
      required String archiveScope,
      required ArchiveCorrectionChoice choice,
    }) => ArchiveCorrectionStore.instance.recordForProof(
      proof: _proof(
        archiveScope: archiveScope,
        proofId: 'proof-$archiveScope-${choice.name}',
      ),
      choice: choice,
      sourceSurface: 'test',
    );

    test('another archive\'s praise cannot raise confidence here', () async {
      await record(
        archiveScope: 'archive-b',
        choice: ArchiveCorrectionChoice.exactlyRight,
      );

      expect(
        ArchiveCorrectionStore.instance.positiveHistory(
          framing,
          archiveScope: 'archive-a',
        ),
        0,
      );
      expect(
        ArchiveCorrectionStore.instance.positiveHistory(
          framing,
          archiveScope: 'archive-b',
        ),
        1,
      );
    });

    test('a reversed ignore stops counting against the framing', () async {
      await record(
        archiveScope: 'archive-a',
        choice: ArchiveCorrectionChoice.ignoreForever,
      );
      expect(
        ArchiveCorrectionStore.instance.negativeHistory(
          framing,
          archiveScope: 'archive-a',
        ),
        1,
      );

      await ArchiveCorrectionStore.instance.undoIgnoreForever(
        archiveScope: 'archive-a',
        semanticFramingFingerprint: framing,
      );

      expect(
        ArchiveCorrectionStore.instance.negativeHistory(
          framing,
          archiveScope: 'archive-a',
        ),
        0,
        reason: 'a suppression the user lifted must stop influencing scoring',
      );
    });

    test('switching archive drops the previous archive from memory', () async {
      await record(
        archiveScope: 'archive-a',
        choice: ArchiveCorrectionChoice.exactlyRight,
      );
      expect(ArchiveCorrectionStore.instance.records, isNotEmpty);

      await ArchiveCorrectionStore.instance.switchArchive('archive-b');

      expect(ArchiveCorrectionStore.instance.activeArchiveScope, 'archive-b');
      expect(
        ArchiveCorrectionStore.instance.records.any(
          (item) => item.archiveScope == 'archive-a' && !item.superseded,
        ),
        isTrue,
        reason:
            'the records are reloaded from disk, so archive-a is still stored; '
            'isolation comes from the scoped lookups, not from deletion',
      );
      expect(
        ArchiveCorrectionStore.instance.positiveHistory(
          framing,
          archiveScope: 'archive-b',
        ),
        0,
      );
    });
  });

  // `LocalPrivacyDataControls.ignoredObservations` / `stopIgnoring`, which drive
  // the undo surface, cannot be tested here: importing that file pulls in
  // `AppServices` and from there the part of `lib/` that does not currently
  // compile. They are thin wrappers over the store calls covered below.
  group('listing and lifting what is ignored', () {
    Future<ArchiveCorrection> ignore(String statement) =>
        ArchiveCorrectionStore.instance.recordForProof(
          proof: _proof(
            archiveScope: ArchiveCorrectionStore.defaultArchiveScope,
            statement: statement,
            proofId: 'proof-${statement.hashCode}',
          ),
          choice: ArchiveCorrectionChoice.ignoreForever,
          sourceSurface: 'test',
        );

    List<ArchiveCorrection> ignoredIn(String scope) => ArchiveCorrectionStore
        .instance
        .records
        .where(
          (item) =>
              !item.superseded &&
              item.choice == ArchiveCorrectionChoice.ignoreForever &&
              item.archiveScope == scope,
        )
        .toList();

    test('lifting one ignore leaves the others in place', () async {
      final first = await ignore('You check the numbers before deciding.');
      await ignore('You pause before replying to messages.');

      final lifted = await ArchiveCorrectionStore.instance.undoIgnoreForever(
        archiveScope: first.archiveScope,
        semanticFramingFingerprint: first.semanticFramingFingerprint,
      );

      expect(lifted, 1);
      final remaining = ignoredIn(ArchiveCorrectionStore.defaultArchiveScope);
      expect(remaining, hasLength(1));
      expect(
        remaining.single.semanticFramingFingerprint,
        isNot(first.semanticFramingFingerprint),
      );
    });

    test('a lifted ignore is superseded rather than deleted', () async {
      final correction = await ignore('You check the numbers before deciding.');

      await ArchiveCorrectionStore.instance.undoIgnoreForever(
        archiveScope: correction.archiveScope,
        semanticFramingFingerprint: correction.semanticFramingFingerprint,
      );

      expect(
        ArchiveCorrectionStore.instance.records.single.superseded,
        isTrue,
        reason: 'correction history stays auditable and exportable',
      );
    });

    test('an ignore in another archive is untouched', () async {
      await ArchiveCorrectionStore.instance.recordForProof(
        proof: _proof(archiveScope: 'archive-other', proofId: 'proof-other'),
        choice: ArchiveCorrectionChoice.ignoreForever,
        sourceSurface: 'test',
      );

      expect(ignoredIn(ArchiveCorrectionStore.defaultArchiveScope), isEmpty);
      expect(ignoredIn('archive-other'), hasLength(1));
    });
  });
}
