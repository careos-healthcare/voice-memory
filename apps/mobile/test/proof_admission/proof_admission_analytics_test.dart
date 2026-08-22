import 'package:archiveme_mobile/features/proof_admission/proof_admission_analytics.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/proof_analytics_guard.dart';
import 'package:flutter_test/flutter_test.dart';

const _statement = 'You check the numbers before deciding.';
const _quote = 'checked the numbers first';
final _at = DateTime.utc(2026, 7);

final _evidence = VerifiedEvidenceSnapshot(
  sourceEntryId: 'entry-1',
  archiveScope: 'archive-1',
  ownerScope: 'owner-1',
  transcriptRevision: 'rev-1',
  transcriptFingerprint: 'transcript-fingerprint-value',
  sourceDate: _at,
  sourceType: ProofSourceType.userTyped,
  quote: _quote,
  startUtf16: 0,
  endUtf16: _quote.length,
  role: ProofEvidenceRole.support,
  verifiedAt: _at,
);

ProofAdmitted _admitted() => ProofAdmitted(
  VerifiedProof(
    proofId: 'proof-1',
    archiveScope: 'archive-1',
    ownerScope: 'owner-1',
    reflection: const Reflection(
      mood: 'steady',
      emotionalIntensity: 3,
      recurringThemes: [],
      exactLanguagePattern: _quote,
      concreteObservation: _statement,
      repeatedSignal: '',
    ),
    claims: [
      VerifiedProofClaim(
        claimId: 'main',
        kind: ProofClaimKind.mainObservation,
        text: _statement,
        evidence: [_evidence],
      ),
    ],
    confidenceBand: ProofConfidenceBand.medium,
    qualityReceipt: ProofQualityReceipt(
      proofType: ProofType.currentObservation,
      confidenceBand: ProofConfidenceBand.medium,
      frequency: ProofFrequency(
        distinctMoments: 2,
        windowStart: _at,
        windowEnd: _at,
      ),
      trend: ProofTrend.insufficientEvidence,
      strengthOverTime: ProofStrengthOverTime.insufficientEvidence,
      supportingEvidence: [_evidence],
      counterexamples: const [],
      contradictions: const [],
      missingEvidence: const [],
      firstOccurrence: _at,
      lastOccurrence: _at,
      generatedAt: _at,
    ),
    verifiedAt: _at,
    sourceRevisionFingerprint: 'source-revision-fingerprint',
    proofFingerprint: 'proof-fingerprint',
    semanticFramingFingerprint: 'semantic-fingerprint',
    wordingFingerprint: 'wording-fingerprint',
  ),
);

Map<String, Object> _payload(ProofAdmissionResult result) =>
    ProofAdmissionAnalytics.payload(
      result: result,
      distinctSourceCount: 2,
      contradictionCount: 0,
      duration: const Duration(milliseconds: 120),
    );

void main() {
  setUp(ProofAnalyticsGuard.resetForTest);

  group('payload shape', () {
    test('an admitted proof reports only bands and tokens', () {
      final payload = _payload(_admitted());

      expect(payload['admission_result'], 'admitted');
      expect(payload['confidence_band'], 'medium');
      expect(payload['source_count_band'], 'few');
      expect(payload['contradiction_count_band'], 'none');
      expect(payload['duration_band'], 'under_250ms');
      expect(payload.containsKey('rejection_reason'), isFalse);
    });

    test('a rejection reports a reason token, not a confidence band', () {
      final payload = _payload(
        const ProofNotAdmitted(
          ProofAdmissionOutcome.invalidStructure,
          reason: 'legacy_response_missing_exact_evidence',
        ),
      );

      expect(payload['admission_result'], 'invalid_structure');
      expect(
        payload['rejection_reason'],
        'legacy_response_missing_exact_evidence',
      );
      expect(payload.containsKey('confidence_band'), isFalse);
    });

    test('every outcome produces a token the guard will accept', () {
      for (final outcome in ProofAdmissionOutcome.values) {
        final payload = _payload(
          ProofNotAdmitted(outcome, reason: 'some reason with spaces'),
        );
        final safe = ProofAnalyticsGuard.sanitize('proof', payload);

        expect(
          safe['admission_result'],
          isNotNull,
          reason: '${outcome.name} must survive the guard',
        );
        expect(safe['rejection_reason'], 'some_reason_with_spaces');
      }
    });

    test('counts are banded so a value cannot single out one archive', () {
      expect(ProofAdmissionAnalytics.countBand(0), 'none');
      expect(ProofAdmissionAnalytics.countBand(1), 'one');
      expect(ProofAdmissionAnalytics.countBand(3), 'few');
      expect(ProofAdmissionAnalytics.countBand(9), 'several');
      expect(ProofAdmissionAnalytics.countBand(400), 'many');
    });

    test('durations are banded rather than reported raw', () {
      expect(
        ProofAdmissionAnalytics.durationBand(const Duration(milliseconds: 3)),
        'under_50ms',
      );
      expect(
        ProofAdmissionAnalytics.durationBand(const Duration(seconds: 30)),
        'over_5s',
      );
    });
  });

  group('leakage', () {
    test('nothing in the payload contains user content', () {
      final serialised = _payload(_admitted()).toString();

      for (final secret in [
        _statement,
        _quote,
        'entry-1',
        'archive-1',
        'proof-fingerprint',
        'semantic-fingerprint',
        'transcript-fingerprint-value',
      ]) {
        expect(serialised, isNot(contains(secret)));
      }
    });

    test('the whole payload survives the guard unchanged', () {
      final payload = _payload(_admitted());

      expect(ProofAnalyticsGuard.sanitize('proof', payload), payload);
      expect(ProofAnalyticsGuard.droppedCount, 0);
    });

    test('content smuggled alongside the payload is refused', () {
      final safe = ProofAnalyticsGuard.sanitize('proof', {
        ..._payload(_admitted()),
        'transcript': 'I checked the numbers again this morning',
        'quote': _quote,
        'entry_id': 'entry-1',
        'archive_id': 'archive-1',
        'fingerprint': 'semantic-fingerprint',
        'raw_score': 12.5,
        'correction_note': 'this felt wrong to me',
        'preferred_wording': 'I like to be sure',
        'file_path': '/Users/someone/archive.json',
        'stack_trace': 'ProviderException at line 4',
      });

      for (final refused in [
        'transcript',
        'quote',
        'entry_id',
        'archive_id',
        'fingerprint',
        'raw_score',
        'correction_note',
        'preferred_wording',
        'file_path',
        'stack_trace',
      ]) {
        expect(safe.containsKey(refused), isFalse, reason: refused);
      }
      expect(safe['admission_result'], 'admitted');
      expect(ProofAnalyticsGuard.droppedCount, 10);
    });

    test('a refusal record keeps the key but never the value', () {
      ProofAnalyticsGuard.sanitize('proof', {
        'transcript': 'I checked the numbers again this morning',
      });

      final drop = ProofAnalyticsGuard.drops.single;
      expect(drop.key, 'transcript');
      expect(drop.toString(), isNot(contains('numbers')));
    });

    test('an allowlisted key still cannot carry free text', () {
      final safe = ProofAnalyticsGuard.sanitize('proof', {
        'rejection_reason': 'the model said "you always avoid this"',
      });

      expect(safe, isEmpty);
    });
  });
}