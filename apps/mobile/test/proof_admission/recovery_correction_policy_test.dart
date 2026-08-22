import 'dart:io';

import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_fingerprints.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

const String _archive = ArchiveCorrectionStore.defaultArchiveScope;
const _owner = 'owner-1';
const _statement = 'Stress at work came right before you skipped the meeting.';
final _at = DateTime.utc(2026, 7);

String _framing(String statement) =>
    ProofFingerprints.semanticFraming(
      statement: statement,
      proofType: 'currentObservation',
    );

VerifiedProof _proof({
  String statement = _statement,
  List<String> sources = const ['entry-1'],
}) {
  final evidence = [
    for (final source in sources)
      VerifiedEvidenceSnapshot(
        sourceEntryId: source,
        archiveScope: _archive,
        ownerScope: _owner,
        transcriptRevision: 'rev-1',
        transcriptFingerprint: 'fingerprint-$source',
        sourceDate: _at,
        sourceType: ProofSourceType.userTyped,
        quote: 'skipped the meeting',
        startUtf16: 0,
        endUtf16: 19,
        role: ProofEvidenceRole.support,
        verifiedAt: _at,
      ),
  ];
  return VerifiedProof(
    proofId: 'proof-${sources.join('-')}',
    archiveScope: _archive,
    ownerScope: _owner,
    reflection: Reflection(
      mood: 'steady',
      emotionalIntensity: 3,
      recurringThemes: const [],
      exactLanguagePattern: 'skipped the meeting',
      concreteObservation: statement,
      repeatedSignal: '',
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
        distinctMoments: sources.length,
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
    proofFingerprint: 'proof-fingerprint-${sources.join('-')}',
    semanticFramingFingerprint: _framing(statement),
    wordingFingerprint: ProofFingerprints.wording(statement),
  );
}

ProofCorrectionQuery _query({
  String statement = _statement,
  Set<String> sources = const {'entry-1'},
}) => ProofCorrectionQuery(
  archiveScope: _archive,
  proofFingerprint: 'proof-fingerprint-follow-up',
  semanticFramingFingerprint: _framing(statement),
  wordingFingerprint: ProofFingerprints.wording(statement),
  evidenceSourceIds: sources,
);

void main() {
  late Directory dir;
  late MobilePrefsStore prefs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recovery_correction_policy');
    prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    ArchiveCorrectionStore.resetForTest();
  });

  tearDown(() async {
    ArchiveCorrectionStore.resetForTest();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('non-recovery lens allows materially new evidence to lift suppression',
      () async {
    ArchiveCorrectionStore.instance.configure(prefs);

    await ArchiveCorrectionStore.instance.recordForProof(
      proof: _proof(),
      choice: ArchiveCorrectionChoice.wrong,
      sourceSurface: 'test',
      now: _at,
    );

    final decision = ArchiveCorrectionStore.instance.decide(
      _query(sources: const {'entry-1', 'entry-2'}),
    );

    expect(decision.suppressed, isFalse);
  });
}