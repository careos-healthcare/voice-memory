import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/evidence_verifier.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/pattern_comparison_executor.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:voicememory_mobile/features/proof_admission/generated/proof_admission_weights.g.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_config.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_candidate.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_candidate_scorer.dart';
import 'package:voicememory_mobile/features/proof_admission/verified_proof_view_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';

const _archive = 'archive-a';
const _owner = 'owner-a';

ProofSourceEntry _source({
  String id = 'entry-1',
  String transcript = 'I said “yes” again 👩🏽‍💻 before checking my calendar.',
  String revision = 'revision-1',
  DateTime? createdAt,
  String archive = _archive,
  bool deleted = false,
  bool archived = false,
}) => ProofSourceEntry(
  entryId: id,
  archiveScope: archive,
  ownerScope: _owner,
  transcript: transcript,
  transcriptRevision: revision,
  createdAt: createdAt ?? DateTime.utc(2026, 7, 1),
  sourceType: ProofSourceType.userTyped,
  deleted: deleted,
  archived: archived,
);

RawModelResponse _legacyRaw({
  String quote = '“yes” again 👩🏽‍💻',
  String observation = 'You described agreeing before checking capacity.',
}) => RawModelResponse(
  payload: {
    'reflection': {
      'mood': 'neutral',
      'emotionalIntensity': 2,
      'recurringThemes': ['capacity'],
      'exactLanguagePattern': quote,
      'concreteObservation': observation,
      'repeatedSignal': 'This always happens.',
      'nextSmallAction': 'Say no next time.',
    },
  },
  receivedAt: DateTime.utc(2026, 7, 2),
);

RawModelResponse _claimsRaw(List<Map<String, dynamic>> claims) =>
    RawModelResponse(
      payload: {
        'reflection': {
          'mood': 'neutral',
          'emotionalIntensity': 2,
          'recurringThemes': ['capacity'],
          'exactLanguagePattern': 'checked',
          'concreteObservation': 'You checked capacity before deciding.',
          'repeatedSignal': 'The same sequence appeared more than once.',
          'claims': claims,
        },
      },
      receivedAt: DateTime.utc(2026, 7, 4),
    );

Map<String, dynamic> _claim({
  required String id,
  required String kind,
  required String text,
  required List<ProofSourceEntry> sources,
  String quote = 'checked',
}) => {
  'id': id,
  'kind': kind,
  'text': text,
  'citations': [
    for (final source in sources)
      {
        'sourceEntryId': source.entryId,
        'quote': quote,
        'role': 'support',
        'sourceRevision': source.transcriptRevision,
      },
  ],
};

void main() {
  group('canonical evidence verifier', () {
    const verifier = CanonicalEvidenceVerifier();

    test('derives one exact UTF-16 range and preserves Unicode quote', () {
      final source = _source();
      final result = verifier.verify(
        citations: [
          EvidenceCitationDraft(
            sourceEntryId: source.entryId,
            quote: '“yes” again 👩🏽‍💻',
            role: ProofEvidenceRole.support,
            sourceRevision: source.transcriptRevision,
          ),
        ],
        sources: {source.entryId: source},
        activeArchiveScope: _archive,
        activeOwnerScope: _owner,
        now: DateTime.utc(2026, 7, 2),
      );

      expect(result.valid, isTrue);
      final evidence = result.evidence.single;
      expect(
        source.transcript.substring(evidence.startUtf16, evidence.endUtf16),
        evidence.quote,
      );
      expect(evidence.quote, '“yes” again 👩🏽‍💻');
      expect(evidence.transcriptFingerprint, hasLength(64));
    });

    test(
      'fails closed for ambiguous quote, stale revision, and wrong archive',
      () {
        final ambiguous = _source(transcript: 'yes, then yes');
        final ambiguousResult = verifier.verify(
          citations: const [
            EvidenceCitationDraft(
              sourceEntryId: 'entry-1',
              quote: 'yes',
              role: ProofEvidenceRole.support,
              sourceRevision: 'revision-1',
            ),
          ],
          sources: {ambiguous.entryId: ambiguous},
          activeArchiveScope: _archive,
          activeOwnerScope: _owner,
          now: DateTime.utc(2026, 7, 2),
        );
        expect(ambiguousResult.valid, isFalse);
        expect(ambiguousResult.outcome, ProofAdmissionOutcome.invalidEvidence);

        final stale = verifier.verify(
          citations: const [
            EvidenceCitationDraft(
              sourceEntryId: 'entry-1',
              quote: 'yes',
              role: ProofEvidenceRole.support,
              sourceRevision: 'old',
            ),
          ],
          sources: {ambiguous.entryId: ambiguous},
          activeArchiveScope: _archive,
          activeOwnerScope: _owner,
          now: DateTime.utc(2026, 7, 2),
        );
        expect(stale.outcome, ProofAdmissionOutcome.stale);

        final wrongArchive = verifier.verify(
          citations: const [
            EvidenceCitationDraft(
              sourceEntryId: 'entry-1',
              quote: 'yes',
              role: ProofEvidenceRole.support,
              sourceRevision: 'revision-1',
            ),
          ],
          sources: {ambiguous.entryId: ambiguous},
          activeArchiveScope: 'archive-b',
          activeOwnerScope: _owner,
          now: DateTime.utc(2026, 7, 2),
        );
        expect(wrongArchive.outcome, ProofAdmissionOutcome.wrongArchive);
      },
    );

    test('rejects deleted, archived, draft, and generated sources', () {
      for (final source in [
        _source(deleted: true),
        _source(archived: true),
        _source(transcript: '[draft] waiting'),
        ProofSourceEntry(
          entryId: 'entry-1',
          archiveScope: _archive,
          ownerScope: _owner,
          transcript: 'generated text',
          transcriptRevision: 'revision-1',
          createdAt: DateTime.utc(2026, 7, 1),
          sourceType: ProofSourceType.generatedPlaceholder,
        ),
      ]) {
        final result = verifier.verify(
          citations: [
            EvidenceCitationDraft(
              sourceEntryId: source.entryId,
              quote: source.transcript,
              role: ProofEvidenceRole.support,
              sourceRevision: source.transcriptRevision,
            ),
          ],
          sources: {source.entryId: source},
          activeArchiveScope: _archive,
          activeOwnerScope: _owner,
          now: DateTime.utc(2026, 7, 2),
        );
        expect(result.valid, isFalse);
      }
    });
  });

  group('canonical proof admission', () {
    test('admits exact legacy evidence but strips unsupported filler', () {
      final source = _source();
      final result =
          CanonicalProofAdmissionService(
            clock: () => DateTime.utc(2026, 7, 2),
          ).admit(
            raw: _legacyRaw(),
            sourceEntries: [source],
            activeArchiveScope: _archive,
            activeOwnerScope: _owner,
            primarySourceEntryId: source.entryId,
          );

      expect(result, isA<ProofAdmitted>());
      final proof = (result as ProofAdmitted).proof;
      expect(proof.reflection.repeatedSignal, isEmpty);
      expect(proof.reflection.nextSmallAction, isNull);
      expect(proof.confidenceBand, ProofConfidenceBand.medium);
      expect(proof.qualityReceipt.frequency.distinctMoments, 1);
      expect(proof.qualityReceipt.frequency.established, isFalse);
      expect(proof.qualityReceipt.proofType, ProofType.currentObservation);
      expect(proof.qualityReceipt.unsupportedClaims, isEmpty);
      expect(
        proof.qualityReceipt.missingEvidence,
        contains(MissingEvidenceReason.needsAnotherDistinctSource),
      );
      expect(proof.claims.single.kind, ProofClaimKind.mainObservation);
    });

    test('keeps supported repeat and removes unsupported trend claim', () {
      final first = _source(
        id: 'first',
        transcript: 'I checked before answering.',
        revision: 'r1',
        createdAt: DateTime.utc(2026, 7, 1),
      );
      final second = _source(
        id: 'second',
        transcript: 'Again I checked before answering.',
        revision: 'r2',
        createdAt: DateTime.utc(2026, 7, 3),
      );
      final raw = _claimsRaw([
        _claim(
          id: 'main',
          kind: 'main_observation',
          text: 'You checked before answering.',
          sources: [second],
        ),
        _claim(
          id: 'repeat',
          kind: 'repeated',
          text: 'The sequence appeared twice.',
          sources: [first, second],
        ),
        _claim(
          id: 'trend',
          kind: 'trend',
          text: 'This is increasing.',
          sources: [first, second],
        ),
      ]);
      final result =
          CanonicalProofAdmissionService(
                clock: () => DateTime.utc(2026, 7, 4),
              ).admit(
                raw: raw,
                sourceEntries: [first, second],
                activeArchiveScope: _archive,
                activeOwnerScope: _owner,
                primarySourceEntryId: second.entryId,
              )
              as ProofAdmitted;

      expect(
        result.proof.claims.map((claim) => claim.kind),
        containsAll([ProofClaimKind.mainObservation, ProofClaimKind.repeated]),
      );
      expect(
        result.proof.claims.map((claim) => claim.kind),
        isNot(contains(ProofClaimKind.trend)),
      );
      expect(
        result.proof.qualityReceipt.unsupportedClaims,
        contains(ProofClaimKind.trend),
      );
    });

    test('stale proof cannot be resurfaced after transcript revision', () {
      final source = _source();
      final service = CanonicalProofAdmissionService(
        clock: () => DateTime.utc(2026, 7, 2),
      );
      final admitted =
          service.admit(
                raw: _legacyRaw(),
                sourceEntries: [source],
                activeArchiveScope: _archive,
                activeOwnerScope: _owner,
                primarySourceEntryId: source.entryId,
              )
              as ProofAdmitted;

      final stale = service.revalidateForDisplay(
        proof: admitted.proof,
        currentSources: [
          _source(
            transcript: '${source.transcript} edited',
            revision: 'revision-2',
          ),
        ],
        activeArchiveScope: _archive,
        activeOwnerScope: _owner,
      );
      expect(stale.outcome, ProofAdmissionOutcome.stale);
    });

    test('durable receipt round-trips and view model omits fingerprints', () {
      final source = _source();
      final admitted =
          CanonicalProofAdmissionService(
                clock: () => DateTime.utc(2026, 7, 2),
              ).admit(
                raw: _legacyRaw(),
                sourceEntries: [source],
                activeArchiveScope: _archive,
                activeOwnerScope: _owner,
                primarySourceEntryId: source.entryId,
              )
              as ProofAdmitted;
      final restored = VerifiedProof.fromJson(admitted.proof.toJson());
      final view = VerifiedProofViewModel.fromVerifiedProof(restored);

      expect(
        restored.qualityReceipt.confidenceBand,
        ProofConfidenceBand.medium,
      );
      expect(view.statement, contains('agreeing'));
      expect(
        jsonEncode(view.evidence.first.quote),
        isNot(contains('revision-')),
      );
      expect(view.evidence.first.quote, isNot(contains('fingerprint')));

      final entry = JournalEntry(
        id: source.entryId,
        createdAt: source.createdAt,
        transcript: source.transcript,
        durationSeconds: 1,
        reflection: restored.reflection,
        verifiedProof: restored,
      );
      final persisted = JournalEntry.fromJson(entry.toJson());
      expect(persisted.verifiedProof?.proofId, restored.proofId);
      expect(
        persisted.reflection.concreteObservation,
        restored.reflection.concreteObservation,
      );
    });

    test('ignore forever correction hard-suppresses the same proof', () async {
      ArchiveCorrectionStore.resetForTest();
      final source = _source();
      final first =
          CanonicalProofAdmissionService(
                correctionPolicy: ArchiveCorrectionStore.instance,
                clock: () => DateTime.utc(2026, 7, 2),
              ).admit(
                raw: _legacyRaw(),
                sourceEntries: [source],
                activeArchiveScope: _archive,
                activeOwnerScope: _owner,
                primarySourceEntryId: source.entryId,
              )
              as ProofAdmitted;
      await ArchiveCorrectionStore.instance.recordForProof(
        proof: first.proof,
        choice: ArchiveCorrectionChoice.ignoreForever,
        sourceSurface: 'test',
        now: DateTime.utc(2026, 7, 3),
      );

      final blocked =
          CanonicalProofAdmissionService(
            correctionPolicy: ArchiveCorrectionStore.instance,
            clock: () => DateTime.utc(2026, 7, 4),
          ).admit(
            raw: _legacyRaw(),
            sourceEntries: [source],
            activeArchiveScope: _archive,
            activeOwnerScope: _owner,
            primarySourceEntryId: source.entryId,
          );
      expect(blocked.outcome, ProofAdmissionOutcome.correctionSuppressed);
    });

    test('clearing the local archive removes correction memory', () async {
      ArchiveCorrectionStore.resetForTest();
      final source = _source();
      ProofAdmissionResult admit() =>
          CanonicalProofAdmissionService(
            correctionPolicy: ArchiveCorrectionStore.instance,
            clock: () => DateTime.utc(2026, 7, 2),
          ).admit(
            raw: _legacyRaw(),
            sourceEntries: [source],
            activeArchiveScope: _archive,
            activeOwnerScope: _owner,
            primarySourceEntryId: source.entryId,
          );

      await ArchiveCorrectionStore.instance.recordForProof(
        proof: (admit() as ProofAdmitted).proof,
        choice: ArchiveCorrectionChoice.ignoreForever,
        sourceSurface: 'test',
        now: DateTime.utc(2026, 7, 3),
      );
      expect(admit().outcome, ProofAdmissionOutcome.correctionSuppressed);

      await ArchiveCorrectionStore.instance.clearAll();

      expect(ArchiveCorrectionStore.instance.records, isEmpty);
      expect(admit().outcome, ProofAdmissionOutcome.admitted);
    });

    test('100 admissions remain deterministic within a bounded local cost', () {
      final source = _source();
      final service = CanonicalProofAdmissionService(
        clock: () => DateTime.utc(2026, 7, 2),
      );
      final stopwatch = Stopwatch()..start();
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        final result =
            service.admit(
                  raw: _legacyRaw(),
                  sourceEntries: [source],
                  activeArchiveScope: _archive,
                  activeOwnerScope: _owner,
                  primarySourceEntryId: source.entryId,
                )
                as ProofAdmitted;
        ids.add(result.proof.proofId);
      }
      stopwatch.stop();
      expect(ids, hasLength(1));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('configured candidate scoring', () {
    test('config is complete, bounded, generated without drift', () async {
      final source = await File(
        'config/proof_admission_weights.v1.json',
      ).readAsString();
      final disk = ProofAdmissionConfig.fromJsonString(source);
      expect(disk.weights, generatedProofAdmissionConfig.weights);
      expect(
        disk.weights.keys.toSet(),
        ProofAdmissionConfig.requiredWeightKeys,
      );

      final invalid = jsonDecode(source) as Map<String, dynamic>;
      (invalid['weights'] as Map<String, dynamic>).remove('coverage');
      expect(
        () => ProofAdmissionConfig.fromJson(invalid),
        throwsFormatException,
      );
      final outOfRange = jsonDecode(source) as Map<String, dynamic>;
      (outOfRange['weights'] as Map<String, dynamic>)['coverage'] = 5.1;
      expect(
        () => ProofAdmissionConfig.fromJson(outOfRange),
        throwsFormatException,
      );
    });

    test('ranking and ties are deterministic and hard safety is excluded', () {
      final scorer = ProofCandidateScorer();
      final alpha = _scoringCandidate('alpha', specificity: 0.8);
      final beta = _scoringCandidate('beta', specificity: 0.2);
      final unsafe = _scoringCandidate('unsafe', hardSafetyPassed: false);
      expect(
        scorer
            .rank([beta, unsafe, alpha])
            .map((item) => item.candidate.stableId),
        ['alpha', 'beta'],
      );
      expect(
        scorer.rank([alpha, beta]).map((item) => item.candidate.stableId),
        scorer.rank([beta, alpha]).map((item) => item.candidate.stableId),
      );
      expect(
        alpha.features.toJson().values.every(
          (value) => value is num || value is bool,
        ),
        isTrue,
      );
    });
  });

  group('comparison admission boundary', () {
    test('raw and deterministic comparison paths require exact chronology', () {
      const executor = PatternComparisonExecutor();
      final past = ArchiveMomentRecord(
        id: 'past',
        createdAt: DateTime.utc(2026, 7, 1),
        savedWords: 'I checked my calendar before saying yes.',
      );
      final current = ArchiveMomentRecord(
        id: 'current',
        createdAt: DateTime.utc(2026, 7, 2),
        savedWords: 'Today I said yes before checking.',
      );
      final plan = executor.buildComparisonPlan(
        currentMoment: current,
        historicalMoments: [past],
        isPro: true,
        hasDismissedProTrailPrompt: true,
      );
      const raw = '''
Label: Changed
Connection: The order changed.
Evidence:
- Past: "checked my calendar"
- Present: "said yes before checking"
What Changed: The decision came before the check.
''';
      final view = executor.buildEvidenceViewStateFromRawOutput(
        plan: plan,
        rawModelOutput: raw,
      );
      expect(view.state, PatternState.changed);
      expect(
        () => executor.buildEvidenceViewStateFromFields(
          plan: plan,
          state: PatternState.changed,
          connectionText: 'Unsupported',
          pastQuote: 'not in the source',
          currentQuote: 'said yes before checking',
          whatChangedText: 'Unsupported',
        ),
        throwsFormatException,
      );
    });
  });
}

ProofCandidate _scoringCandidate(
  String id, {
  double specificity = 0.5,
  bool hardSafetyPassed = true,
}) => ProofCandidate(
  stableId: id,
  isValid: true,
  hardSafetyPassed: hardSafetyPassed,
  features: ProofFeatureVector(
    coverage: 1,
    specificity: specificity,
    citationCount: 1,
    sourceCount: 1,
    chronology: 0,
    sourceDiversity: 1,
    citationSourceRatio: 1,
    corroborationRatio: 1,
    contradiction: 0,
    recency: 1,
    freshness: 1,
    transcriptSpecificity: 0.5,
    userConfirmed: false,
    correctionHistoryCount: 0,
    acceptedCorrectionRatio: 0,
    positiveCorrectionHistory: 0,
    negativeCorrectionHistory: 0,
    wordingRejectionHistory: 0,
    evidenceRejectionHistory: 0,
    oneEntryPenalty: true,
    stalePenalty: false,
    modelConfidence: 0.5,
    deterministicFallback: 0,
  ),
);
