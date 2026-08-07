import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_fingerprints.dart';
import 'package:voicememory_mobile/models/reflection.dart';

const _archive = 'archive-1';
const _otherArchive = 'archive-2';
const _owner = 'owner-1';
const _statement = 'You check the numbers before deciding.';
final _at = DateTime.utc(2026, 7, 1);

String _framing(String statement, {String type = 'currentObservation'}) =>
    ProofFingerprints.semanticFraming(statement: statement, proofType: type);

VerifiedProof _proof({
  String statement = _statement,
  List<String> sources = const ['entry-1'],
  String archiveScope = _archive,
}) {
  final evidence = [
    for (final source in sources)
      VerifiedEvidenceSnapshot(
        sourceEntryId: source,
        archiveScope: archiveScope,
        ownerScope: _owner,
        transcriptRevision: 'rev-1',
        transcriptFingerprint: 'fingerprint-$source',
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
    proofId: 'proof-${sources.join('-')}',
    archiveScope: archiveScope,
    ownerScope: _owner,
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
  String archiveScope = _archive,
  String proofFingerprint = 'proof-fingerprint-entry-1',
}) => ProofCorrectionQuery(
  archiveScope: archiveScope,
  proofFingerprint: proofFingerprint,
  semanticFramingFingerprint: _framing(statement),
  wordingFingerprint: ProofFingerprints.wording(statement),
  evidenceSourceIds: sources,
);

Future<ArchiveCorrection> _record(
  ArchiveCorrectionChoice choice, {
  VerifiedProof? proof,
  List<String> disputedEvidenceRefs = const [],
  String? preferredWording,
}) => ArchiveCorrectionStore.instance.recordForProof(
  proof: proof ?? _proof(),
  choice: choice,
  sourceSurface: 'test',
  disputedEvidenceRefs: disputedEvidenceRefs,
  preferredWording: preferredWording,
  now: _at,
);

void main() {
  setUp(ArchiveCorrectionStore.resetForTest);

  group('semantic framing fingerprint', () {
    test('trivial paraphrases collapse onto one identity', () {
      expect(
        _framing('You check the numbers before deciding.'),
        _framing('you   CHECK the number, before deciding'),
      );
      expect(
        _framing('You check the numbers before deciding.'),
        _framing('Before deciding, you are checking the numbers!'),
      );
    });

    test('a different subject is a different identity', () {
      expect(
        _framing('You check the numbers before deciding.'),
        isNot(_framing('You avoid difficult conversations.')),
      );
    });

    test('the same words as an observation and as a repeat differ', () {
      expect(
        _framing(_statement),
        isNot(_framing(_statement, type: 'repeatedSignal')),
      );
    });

    test('wording changes even when the framing does not', () {
      expect(
        ProofFingerprints.wording('You check the numbers before deciding.'),
        isNot(ProofFingerprints.wording('Before deciding you check numbers.')),
      );
    });
  });

  group('exactly right', () {
    test('does not suppress and does not cap confidence', () async {
      await _record(ArchiveCorrectionChoice.exactlyRight);
      final decision = ArchiveCorrectionStore.instance.decide(_query());

      expect(decision.suppressed, isFalse);
      expect(decision.confidenceCap, isNull);
      expect(
        ArchiveCorrectionStore.instance.positiveHistory(_framing(_statement)),
        1,
      );
    });

    test('cannot override an earlier ignore forever', () async {
      await _record(ArchiveCorrectionChoice.ignoreForever);
      await _record(ArchiveCorrectionChoice.exactlyRight);

      final decision = ArchiveCorrectionStore.instance.decide(_query());
      expect(decision.suppressed, isTrue);
      expect(decision.suppressionReason, 'ignore_forever');
    });
  });

  group('partly right', () {
    test('caps confidence instead of suppressing', () async {
      await _record(ArchiveCorrectionChoice.partlyRight);
      final decision = ArchiveCorrectionStore.instance.decide(_query());

      expect(decision.suppressed, isFalse);
      expect(decision.confidenceCap, ProofConfidenceBand.medium);
    });

    test('the cap lifts once a new distinct source appears', () async {
      await _record(ArchiveCorrectionChoice.partlyRight);
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(sources: {'entry-1', 'entry-2'}),
      );

      expect(decision.confidenceCap, isNull);
    });
  });

  group('wrong', () {
    test('suppresses the same framing', () async {
      await _record(ArchiveCorrectionChoice.wrong);
      final decision = ArchiveCorrectionStore.instance.decide(_query());

      expect(decision.suppressed, isTrue);
      expect(decision.suppressionReason, 'framing_rejected_as_wrong');
    });

    test('suppresses a trivial paraphrase of the same framing', () async {
      await _record(ArchiveCorrectionChoice.wrong);
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(statement: 'Before deciding, you are checking the numbers!'),
      );

      expect(decision.suppressed, isTrue);
    });

    test('leaves an unrelated framing alone', () async {
      await _record(ArchiveCorrectionChoice.wrong);
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(
          statement: 'You avoid difficult conversations.',
          proofFingerprint: 'other-proof',
        ),
      );

      expect(decision.suppressed, isFalse);
    });

    test('materially new evidence lets the framing return', () async {
      await _record(ArchiveCorrectionChoice.wrong);
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(sources: {'entry-1', 'entry-2'}, proofFingerprint: 'other'),
      );

      expect(decision.suppressed, isFalse);
    });

    test('the same evidence seen later is not materially new', () async {
      await _record(ArchiveCorrectionChoice.wrong);
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(sources: {'entry-1'}, proofFingerprint: 'a-newer-proof'),
      );

      expect(
        decision.suppressed,
        isTrue,
        reason: 'time passing is not new evidence',
      );
    });
  });

  group('wrong wording', () {
    test('a preferred label renames without suppressing', () async {
      await _record(
        ArchiveCorrectionChoice.wrongWording,
        preferredWording: 'I like to be sure before I commit.',
      );
      final decision = ArchiveCorrectionStore.instance.decide(_query());

      expect(decision.suppressed, isFalse);
      expect(decision.preferredWording, 'I like to be sure before I commit.');
    });

    test('a rejected phrasing with no replacement is withheld', () async {
      await _record(ArchiveCorrectionChoice.wrongWording);
      final decision = ArchiveCorrectionStore.instance.decide(_query());

      expect(decision.suppressed, isTrue);
      expect(decision.suppressionReason, 'wording_rejected');
    });

    test('a different phrasing of the same relationship survives', () async {
      await _record(ArchiveCorrectionChoice.wrongWording);
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(statement: 'Before deciding you check numbers.'),
      );

      expect(decision.suppressed, isFalse);
    });

    test('the label chosen for this exact sentence wins', () async {
      // Both records reach this candidate: one through the sentence, one
      // through the shared framing. Which label applies must not depend on the
      // order the corrections happen to be stored in.
      const otherPhrasing = 'Before deciding you check numbers.';
      await _record(
        ArchiveCorrectionChoice.wrongWording,
        proof: _proof(statement: otherPhrasing),
        preferredWording: 'the framing match',
      );
      await _record(
        ArchiveCorrectionChoice.wrongWording,
        preferredWording: 'the sentence match',
      );

      expect(
        ArchiveCorrectionStore.instance.decide(_query()).preferredWording,
        'the sentence match',
      );
    });

    test('the newest label wins between equally good matches', () async {
      // Two separate proofs, so neither correction supersedes the other, but
      // the same sentence, so both match this candidate equally well.
      await ArchiveCorrectionStore.instance.recordForProof(
        proof: _proof(sources: const ['entry-2']),
        choice: ArchiveCorrectionChoice.wrongWording,
        sourceSurface: 'test',
        preferredWording: 'the newer label',
        now: _at.add(const Duration(days: 1)),
      );
      await _record(
        ArchiveCorrectionChoice.wrongWording,
        preferredWording: 'the older label',
      );

      expect(
        ArchiveCorrectionStore.instance.decide(_query()).preferredWording,
        'the newer label',
        reason: 'not simply the first one stored',
      );
    });
  });

  group('wrong evidence', () {
    test('disallows only the disputed citations', () async {
      await _record(
        ArchiveCorrectionChoice.wrongEvidence,
        proof: _proof(sources: ['entry-1', 'entry-2']),
        disputedEvidenceRefs: ['entry-2'],
      );
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(sources: {'entry-1', 'entry-2'}),
      );

      expect(decision.suppressed, isFalse);
      expect(decision.disallowedEvidenceSourceIds, {'entry-2'});
    });

    test('with no subset named, the whole citation set is disputed', () async {
      await _record(ArchiveCorrectionChoice.wrongEvidence);
      final decision = ArchiveCorrectionStore.instance.decide(_query());

      expect(decision.disallowedEvidenceSourceIds, contains('entry-1'));
    });
  });

  group('ignore forever', () {
    test('is durable across a store reload', () async {
      await _record(ArchiveCorrectionChoice.ignoreForever);
      final records = ArchiveCorrectionStore.instance.records
          .map((item) => item.toJson())
          .toList();

      ArchiveCorrectionStore.resetForTest();
      for (final row in records) {
        expect(
          ArchiveCorrection.fromJson(row).choice,
          ArchiveCorrectionChoice.ignoreForever,
        );
      }
    });

    test('never reaches another archive', () async {
      await _record(ArchiveCorrectionChoice.ignoreForever);
      final decision = ArchiveCorrectionStore.instance.decide(
        _query(archiveScope: _otherArchive),
      );

      expect(decision.suppressed, isFalse);
    });

    test('clearing the archive reverses it', () async {
      await _record(ArchiveCorrectionChoice.ignoreForever);
      await ArchiveCorrectionStore.instance.clearAll();

      expect(
        ArchiveCorrectionStore.instance.decide(_query()).suppressed,
        isFalse,
      );
    });

    test('an explicit undo reverses it and keeps the history', () async {
      await _record(ArchiveCorrectionChoice.ignoreForever);
      final reversed = await ArchiveCorrectionStore.instance.undoIgnoreForever(
        archiveScope: _archive,
        semanticFramingFingerprint: _framing(_statement),
        now: _at,
      );

      expect(reversed, 1);
      expect(
        ArchiveCorrectionStore.instance.decide(_query()).suppressed,
        isFalse,
      );
      expect(ArchiveCorrectionStore.instance.records.single.superseded, isTrue);
    });

    test('an undo in one archive does not touch another', () async {
      await _record(ArchiveCorrectionChoice.ignoreForever);
      final reversed = await ArchiveCorrectionStore.instance.undoIgnoreForever(
        archiveScope: _otherArchive,
        semanticFramingFingerprint: _framing(_statement),
        now: _at,
      );

      expect(reversed, 0);
      expect(
        ArchiveCorrectionStore.instance.decide(_query()).suppressed,
        isTrue,
      );
    });
  });

  group('record shape', () {
    test('a superseded correction stops applying', () async {
      await _record(ArchiveCorrectionChoice.wrong);
      await _record(ArchiveCorrectionChoice.exactlyRight);

      final decision = ArchiveCorrectionStore.instance.decide(_query());
      expect(decision.suppressed, isFalse);
    });

    test(
      'a preferred label round trips and stays out of the fingerprint',
      () async {
        final correction = await _record(
          ArchiveCorrectionChoice.wrongWording,
          preferredWording: 'I like to be sure.',
        );
        final restored = ArchiveCorrection.fromJson(correction.toJson());

        expect(restored.preferredWording, 'I like to be sure.');
        expect(restored.correctionId, isNot(contains('sure')));
        expect(restored.semanticFramingFingerprint, isNot(contains('sure')));
      },
    );
  });
}
