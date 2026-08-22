import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/proof/verified_proof_correction_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    await tester.tap(find.text('Partly right'));
    await tester.pump();
    expect(find.byKey(const Key('proof_correction_saved')), findsOneWidget);
    expect(ArchiveCorrectionStore.instance.records, hasLength(1));
    expect(
      ArchiveCorrectionStore.instance.records.single.choice,
      ArchiveCorrectionChoice.partlyRight,
    );
  });

  testWidgets('ignore forever cannot be committed by a single tap', (
    tester,
  ) async {
    ArchiveCorrectionStore.resetForTest();
    await _pumpControls(tester);

    await tester.tap(find.text('Ignore forever'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('proof_correction_ignore_confirm')),
      findsOneWidget,
    );
    expect(ArchiveCorrectionStore.instance.records, isEmpty);

    await tester.tap(find.byKey(const Key('proof_correction_ignore_cancel')));
    await tester.pumpAndSettle();

    expect(
      ArchiveCorrectionStore.instance.records,
      isEmpty,
      reason: 'cancelling must leave no durable suppression behind',
    );
  });

  testWidgets('confirming ignore forever records the suppression', (
    tester,
  ) async {
    ArchiveCorrectionStore.resetForTest();
    await _pumpControls(tester);

    await tester.tap(find.text('Ignore forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proof_correction_ignore_accept')));
    await tester.pumpAndSettle();

    expect(
      ArchiveCorrectionStore.instance.records.single.choice,
      ArchiveCorrectionChoice.ignoreForever,
    );
  });

  testWidgets('wrong evidence records only the citations the user named', (
    tester,
  ) async {
    ArchiveCorrectionStore.resetForTest();
    await _pumpControls(tester);

    await tester.tap(find.text('Wrong evidence'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('proof_correction_evidence_picker')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('proof_correction_evidence_entry-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proof_correction_evidence_save')));
    await tester.pumpAndSettle();

    final saved = ArchiveCorrectionStore.instance.records.single;
    expect(saved.choice, ArchiveCorrectionChoice.wrongEvidence);
    expect(saved.disputedEvidenceRefs, ['entry-1']);
  });

  testWidgets('backing out of the evidence picker saves nothing', (
    tester,
  ) async {
    ArchiveCorrectionStore.resetForTest();
    await _pumpControls(tester);

    await tester.tap(find.text('Wrong evidence'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proof_correction_evidence_cancel')));
    await tester.pumpAndSettle();

    expect(ArchiveCorrectionStore.instance.records, isEmpty);
  });
}

Future<void> _pumpControls(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: VerifiedProofCorrectionControls(
        proof: _proof(),
        sourceSurface: 'test_surface',
      ),
    ),
  ),
);

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
      proofType: ProofType.currentObservation,
      confidenceBand: ProofConfidenceBand.medium,
      frequency: ProofFrequency(
        distinctMoments: 1,
        windowStart: at,
        windowEnd: at,
      ),
      trend: ProofTrend.insufficientEvidence,
      strengthOverTime: ProofStrengthOverTime.insufficientEvidence,
      supportingEvidence: [evidence],
      counterexamples: const [],
      contradictions: const [],
      missingEvidence: const [],
      firstOccurrence: at,
      lastOccurrence: at,
      generatedAt: at,
    ),
    verifiedAt: at,
    sourceRevisionFingerprint: 'source-revision-fingerprint',
    proofFingerprint: 'proof-fingerprint',
    semanticFramingFingerprint: 'semantic-fingerprint',
    wordingFingerprint: 'wording-fingerprint',
  );
}