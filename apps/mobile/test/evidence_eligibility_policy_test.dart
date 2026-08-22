import 'package:archiveme_mobile/features/archive_changes/archive_changes_eligibility.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/evidence_contract/derived_claim.dart';
import 'package:archiveme_mobile/features/evidence_contract/derived_claim_mapper.dart';
import 'package:archiveme_mobile/features/evidence_contract/derived_claim_render_gate.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_copy.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/features/post_save/post_save_repeat_copy.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_model.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/record/moment_save_receipt_card.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DerivedClaimEvidenceRef _ref({
  required String id,
  required DateTime date,
  String quote = 'sample quote',
  bool hidden = false,
  bool deleted = false,
}) => DerivedClaimEvidenceRef(
  entryId: id,
  quote: quote,
  sourceDate: date,
  hidden: hidden,
  deleted: deleted,
);

VerifiedEvidenceSnapshot _snapshot({
  required String id,
  required DateTime date,
  String quote = 'sample quote',
}) => VerifiedEvidenceSnapshot(
  sourceEntryId: id,
  archiveScope: 'local',
  ownerScope: 'owner',
  transcriptRevision: 'rev',
  transcriptFingerprint: 'fp',
  sourceDate: date,
  sourceType: ProofSourceType.userVoiceTranscript,
  quote: quote,
  startUtf16: 0,
  endUtf16: quote.length,
  role: ProofEvidenceRole.support,
  verifiedAt: date,
);

JournalEntry _entry({String id = 'e1', String transcript = 'I said yes again.'}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 8, 12),
      transcript: transcript,
      durationSeconds: 10,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

DailyMirrorResult _mirror({List<String> terms = const ['yes', 'calendar']}) =>
    DailyMirrorResult(
      stage: DailyMirrorStage.possibleLoop,
      heroTitle: EvidenceEligibilityCopy.relatedMomentsTitle,
      heroBody: EvidenceEligibilityCopy.relatedMomentsBody,
      primaryCta: 'Record another',
      hasGroundedEvidence: true,
      hasChange: false,
      evidenceTerms: terms,
      evidenceEntryIds: const ['e1', 'e2'],
    );

void main() {
  group('EvidenceEligibilityPolicy thresholds', () {
    test('one moment is saved-content only', () {
      expect(
        EvidenceEligibilityPolicy.evaluateSavedContentOnly(1),
        EvidenceEligibilityOutcome.savedContentOnly,
      );
      expect(
        EvidenceEligibilityPolicy.evaluateRelatedMoments(
          evidenceRefs: [_ref(id: 'a', date: DateTime(2026, 8, 1))],
          bothEvidenceVisible: true,
        ),
        EvidenceEligibilityOutcome.insufficientMoments,
      );
    });

    test('two related admitted moments may surface relationship copy', () {
      final refs = [
        _ref(id: 'a', date: DateTime(2026, 8, 1)),
        _ref(id: 'b', date: DateTime(2026, 8, 2)),
      ];
      expect(
        EvidenceEligibilityPolicy.evaluateRelatedMoments(
          evidenceRefs: refs,
          bothEvidenceVisible: true,
        ),
        EvidenceEligibilityOutcome.allowed,
      );
    });

    test('same-day moments do not unlock possible pattern', () {
      final sameDay = [
        _ref(id: 'a', date: DateTime(2026, 8, 1, 9)),
        _ref(id: 'b', date: DateTime(2026, 8, 1, 11)),
        _ref(id: 'c', date: DateTime(2026, 8, 1, 15)),
      ];
      expect(
        EvidenceEligibilityPolicy.evaluatePossiblePattern(
          evidenceRefs: sameDay,
        ),
        EvidenceEligibilityOutcome.insufficientTimeSeparation,
      );
    });

    test('separated moments unlock possible pattern at 3+', () {
      final separated = [
        _ref(id: 'a', date: DateTime(2026, 8, 1)),
        _ref(id: 'b', date: DateTime(2026, 8, 2)),
        _ref(id: 'c', date: DateTime(2026, 8, 4)),
      ];
      expect(
        EvidenceEligibilityPolicy.evaluatePossiblePattern(
          evidenceRefs: separated,
        ),
        EvidenceEligibilityOutcome.allowed,
      );
    });

    test('change requires explicit comparison and time separation', () {
      final then = _snapshot(id: 'a', date: DateTime(2026, 7, 1));
      final now = _snapshot(id: 'b', date: DateTime(2026, 7, 2));
      final refs = [
        DerivedClaimEvidenceRef.fromVerifiedSnapshot(then),
        DerivedClaimEvidenceRef.fromVerifiedSnapshot(now),
      ];
      expect(
        EvidenceEligibilityPolicy.evaluateChange(
          evidenceRefs: refs,
          hasExplicitComparison: true,
          thenEvidence: then,
          nowEvidence: now,
        ),
        EvidenceEligibilityOutcome.allowed,
      );
      expect(
        EvidenceEligibilityPolicy.evaluateChange(
          evidenceRefs: refs,
          hasExplicitComparison: true,
          thenEvidence: now,
          nowEvidence: then,
        ),
        EvidenceEligibilityOutcome.noExplicitComparison,
      );
    });

    test('hidden or deleted evidence invalidates render', () {
      final claim = DerivedClaim(
        claimId: 'claim-1',
        kind: DerivedClaimKind.relatedMoments,
        displayText: EvidenceEligibilityCopy.relatedMomentsBody,
        evidenceRefs: [
          _ref(id: 'a', date: DateTime(2026, 8, 1), hidden: true),
          _ref(id: 'b', date: DateTime(2026, 8, 2), deleted: true),
        ],
        evidenceRangeStart: DateTime(2026, 8, 1),
        evidenceRangeEnd: DateTime(2026, 8, 2),
        generation: const DerivedClaimGenerationMeta(method: 'test'),
        eligibilityReason: 'related_moments',
        eligibilityPolicyVersion: 1,
        userStatus: DerivedClaimUserStatus.unreviewed,
        createdAt: DateTime(2026, 8, 12),
        updatedAt: DateTime(2026, 8, 12),
      );
      expect(DerivedClaimRenderGate.renderableClaim(claim), isNull);
    });

    test('notForMe and hidden user status suppress render', () {
      final base = DerivedClaim(
        claimId: 'claim-2',
        kind: DerivedClaimKind.relatedMoments,
        displayText: EvidenceEligibilityCopy.relatedMomentsBody,
        evidenceRefs: [
          _ref(id: 'a', date: DateTime(2026, 8, 1)),
          _ref(id: 'b', date: DateTime(2026, 8, 2)),
        ],
        evidenceRangeStart: DateTime(2026, 8, 1),
        evidenceRangeEnd: DateTime(2026, 8, 2),
        generation: const DerivedClaimGenerationMeta(method: 'test'),
        eligibilityReason: 'related_moments',
        eligibilityPolicyVersion: 1,
        userStatus: DerivedClaimUserStatus.notForMe,
        createdAt: DateTime(2026, 8, 12),
        updatedAt: DateTime(2026, 8, 12),
      );
      expect(DerivedClaimRenderGate.renderableClaim(base), isNull);
      expect(
        DerivedClaimRenderGate.renderableClaim(
          DerivedClaim(
            claimId: base.claimId,
            kind: base.kind,
            displayText: base.displayText,
            evidenceRefs: base.evidenceRefs,
            evidenceRangeStart: base.evidenceRangeStart,
            evidenceRangeEnd: base.evidenceRangeEnd,
            generation: base.generation,
            eligibilityReason: base.eligibilityReason,
            eligibilityPolicyVersion: base.eligibilityPolicyVersion,
            userStatus: DerivedClaimUserStatus.hidden,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
          ),
        ),
        isNull,
      );
    });

    test('recomputeAfterEvidenceChange marks missing evidence safely', () {
      final claim = DerivedClaim(
        claimId: 'claim-3',
        kind: DerivedClaimKind.possiblePattern,
        displayText: EvidenceEligibilityCopy.possiblePatternBody,
        evidenceRefs: [
          _ref(id: 'a', date: DateTime(2026, 8, 1)),
          _ref(id: 'b', date: DateTime(2026, 8, 3), deleted: true),
          _ref(id: 'c', date: DateTime(2026, 8, 5)),
        ],
        evidenceRangeStart: DateTime(2026, 8, 1),
        evidenceRangeEnd: DateTime(2026, 8, 5),
        generation: const DerivedClaimGenerationMeta(method: 'test'),
        eligibilityReason: 'possible_pattern',
        eligibilityPolicyVersion: 1,
        userStatus: DerivedClaimUserStatus.unreviewed,
        createdAt: DateTime(2026, 8, 12),
        updatedAt: DateTime(2026, 8, 12),
      );
      final recomputed = DerivedClaimRenderGate.recomputeAfterEvidenceChange(
        claim,
      );
      expect(recomputed.availableEvidenceRefs, hasLength(2));
      expect(
        DerivedClaimRenderGate.eligibilityForClaim(recomputed),
        isNot(EvidenceEligibilityOutcome.allowed),
      );
    });

    test('user correction maps to derived claim status without rewriting moment',
        () {
      expect(
        userStatusFromCorrection('exactlyRight'),
        DerivedClaimUserStatus.fits,
      );
      expect(
        userStatusFromCorrection('partlyRight'),
        DerivedClaimUserStatus.partlyFits,
      );
      expect(
        userStatusFromCorrection('ignoreForever'),
        DerivedClaimUserStatus.notForMe,
      );
    });

    test('zero moments stays saved-content only', () {
      expect(
        EvidenceEligibilityPolicy.evaluateSavedContentOnly(0),
        EvidenceEligibilityOutcome.savedContentOnly,
      );
    });

    test('malformed provider output without evidence does not render', () {
      final claim = VerifiedProofClaim(
        claimId: 'x',
        kind: ProofClaimKind.repeated,
        text: 'This repeats.',
        evidence: const [],
      );
      expect(DerivedClaimRenderGate.renderableProofClaim(claim), isNull);
    });

    test('admission delegates source minimums to policy', () {
      final service = CanonicalProofAdmissionService();
      expect(
        EvidenceEligibilityPolicy.admissionFailureFor(
          kind: ProofClaimKind.repeated,
          evidence: [_snapshot(id: 'a', date: DateTime(2026, 8, 1))],
        ),
        '${ProofClaimKind.repeated.name}_source_minimum',
      );
      expect(service, isNotNull);
    });
  });

  group('UI contract', () {
    testWidgets('one-moment receipt shows no relationship copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MomentSaveReceiptCard(
              entry: _entry(),
              entryCount: 1,
              mirror: _mirror(),
              onRecordAnother: () {},
              onViewArchive: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('moment_save_receipt_relationship')),
          findsNothing);
      expect(find.textContaining('pattern'), findsNothing);
    });

    testWidgets('two-moment receipt shows tentative related copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MomentSaveReceiptCard(
              entry: _entry(),
              entryCount: 2,
              mirror: _mirror(),
              onRecordAnother: () {},
              onViewArchive: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('moment_save_receipt_relationship')),
          findsOneWidget);
      expect(find.text(EvidenceEligibilityCopy.relatedMomentsBody), findsOneWidget);
    });

    test('two-moment post-save repeat copy stays tentative', () {
      final display = PostSaveRepeatCopy.resolve(
        _mirror(),
        admittedMomentCount: 2,
      );
      expect(display.show, isTrue);
      expect(display.body, EvidenceEligibilityCopy.relatedMomentsBody);
    });
  });

  group('Changes eligibility', () {
    test('requires policy minimum moments and timeline items', () {
      final entries = List.generate(
        3,
        (index) => _entry(id: 'e$index', transcript: 'Enough detail here $index'),
      );
      expect(
        ArchiveChangesEligibility.isEligible(entries: entries, timeline: const []),
        isFalse,
      );
    });
  });

  group('Persistence and export', () {
    test('derived claim round trips through json', () {
      final original = DerivedClaim(
        claimId: 'claim-abc',
        kind: DerivedClaimKind.possiblePattern,
        displayText: EvidenceEligibilityCopy.possiblePatternBody,
        evidenceRefs: [
          _ref(id: 'a', date: DateTime(2026, 8, 1)),
          _ref(id: 'b', date: DateTime(2026, 8, 3)),
          _ref(id: 'c', date: DateTime(2026, 8, 5)),
        ],
        evidenceRangeStart: DateTime(2026, 8, 1),
        evidenceRangeEnd: DateTime(2026, 8, 5),
        generation: const DerivedClaimGenerationMeta(method: 'test'),
        eligibilityReason: 'possible_pattern',
        eligibilityPolicyVersion: EvidenceEligibilityPolicy.policyVersion,
        userStatus: DerivedClaimUserStatus.partlyFits,
        createdAt: DateTime(2026, 8, 12),
        updatedAt: DateTime(2026, 8, 12),
      );
      final restored = DerivedClaim.fromJson(original.toJson());
      expect(restored.claimId, original.claimId);
      expect(restored.userStatus, DerivedClaimUserStatus.partlyFits);
      expect(restored.evidenceRefs, hasLength(3));
    });

    test('export distinguishes your words from suggestion', () {
      final proof = VerifiedProof(
        proofId: 'proof-1',
        archiveScope: 'local',
        ownerScope: 'owner',
        reflection: Reflection(
          mood: 'neutral',
          emotionalIntensity: 0,
          recurringThemes: const [],
          exactLanguagePattern: '',
          concreteObservation: 'Suggestion text',
          repeatedSignal: '',
        ),
        claims: [
          VerifiedProofClaim(
            claimId: 'claim-1',
            kind: ProofClaimKind.mainObservation,
            text: 'Suggestion text',
            evidence: [
              _snapshot(id: 'e1', date: DateTime(2026, 8, 1), quote: 'Your words'),
            ],
          ),
        ],
        confidenceBand: ProofConfidenceBand.low,
        qualityReceipt: ProofQualityReceipt(
          proofType: ProofType.currentObservation,
          confidenceBand: ProofConfidenceBand.low,
          frequency: const ProofFrequency.none(),
          trend: ProofTrend.insufficientEvidence,
          strengthOverTime: ProofStrengthOverTime.insufficientEvidence,
          supportingEvidence: const [],
          counterexamples: const [],
          contradictions: const [],
          missingEvidence: const [],
          firstOccurrence: null,
          lastOccurrence: null,
          generatedAt: DateTime(2026, 8, 12),
        ),
        verifiedAt: DateTime(2026, 8, 12),
        sourceRevisionFingerprint: 'src',
        proofFingerprint: 'proof',
        semanticFramingFingerprint: 'sem',
        wordingFingerprint: 'word',
      );
      final derived = DerivedClaimMapper.fromVerifiedProofClaim(
        claim: proof.claims.first,
        proof: proof,
        createdAt: DateTime(2026, 8, 12),
      );
      final export = DerivedClaimMapper.exportSectionFor(derived);
      expect(export[EvidenceEligibilityCopy.exportSuggestionLabel], isNotNull);
      expect(export[EvidenceEligibilityCopy.exportYourWordsLabel], ['Your words']);
    });
  });

  group('ArchiveEvidenceGuard uses focused-beta policy minimum', () {
    test('minimum evidence count follows policy in V1 mode', () {
      expect(
        ArchiveEvidenceGuard.minimumEvidenceCount,
        EvidenceEligibilityPolicy.possiblePatternMinimum,
      );
    });
  });
}
