import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/proof/verified_proof_correction_controls.dart';

void main() {
  testWidgets('shows all canonical choices and saves structural feedback', (
    tester,
  ) async {
    ArchiveCorrectionStore.resetForTest();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerifiedProofCorrectionControls(
            proof: _proof(),
            sourceSurface: 'test_surface',
          ),
        ),
      ),
    );

    for (final label in [
      'Exactly right',
      'Partly right',
      'Wrong',
      'Wrong wording',
      'Wrong evidence',
      'Ignore forever',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Wrong evidence'));
    await tester.pump();
    expect(find.byKey(const Key('proof_correction_saved')), findsOneWidget);
    expect(ArchiveCorrectionStore.instance.records, hasLength(1));
    expect(
      ArchiveCorrectionStore.instance.records.single.choice,
      ArchiveCorrectionChoice.wrongEvidence,
    );
  });
}

VerifiedProof _proof() {
  final at = DateTime.utc(2026, 8, 4);
  const reflection = Reflection(
    mood: 'neutral',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: 'checked first',
    concreteObservation: 'You checked before deciding.',
    repeatedSignal: '',
  );
  final evidence = VerifiedEvidenceSnapshot(
    sourceEntryId: 'entry-1',
    archiveScope: 'archive-1',
    ownerScope: 'owner-1',
    transcriptRevision: 'revision-1',
    transcriptFingerprint: 'fingerprint',
    sourceDate: at,
    sourceType: ProofSourceType.userTyped,
    quote: 'checked first',
    startUtf16: 2,
    endUtf16: 15,
    role: ProofEvidenceRole.support,
    verifiedAt: at,
  );
  return VerifiedProof(
    proofId: 'proof-1',
    archiveScope: 'archive-1',
    ownerScope: 'owner-1',
    reflection: reflection,
    claims: [
      VerifiedProofClaim(
        claimId: 'main',
        kind: ProofClaimKind.mainObservation,
        text: reflection.concreteObservation,
        evidence: [evidence],
      ),
    ],
    confidenceBand: ProofConfidenceBand.medium,
    qualityReceipt: ProofQualityReceipt(
      repeatFrequency: 1,
      trend: 'not_established',
      confidenceBand: ProofConfidenceBand.medium,
      counterexamples: 0,
      missingEvidence: const [],
      strengthOverTime: 'not_established',
      firstOccurrence: at,
      lastOccurrence: at,
      contradictions: 0,
    ),
    verifiedAt: at,
    sourceRevisionFingerprint: 'source-revision-fingerprint',
    proofFingerprint: 'proof-fingerprint',
    semanticFramingFingerprint: 'semantic-fingerprint',
    wordingFingerprint: 'wording-fingerprint',
  );
}
