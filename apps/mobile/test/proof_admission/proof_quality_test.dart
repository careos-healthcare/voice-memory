import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/verified_proof_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _archive = 'archive-1';
const _owner = 'owner-1';
final _now = DateTime.utc(2026, 8);

VerifiedEvidenceSnapshot _snapshot(
  String entryId,
  String quote,
  DateTime at, {
  ProofEvidenceRole role = ProofEvidenceRole.support,
}) => VerifiedEvidenceSnapshot(
  sourceEntryId: entryId,
  archiveScope: _archive,
  ownerScope: _owner,
  transcriptRevision: 'rev-1',
  transcriptFingerprint: 'fingerprint-$entryId',
  sourceDate: at,
  sourceType: ProofSourceType.userTyped,
  quote: quote,
  startUtf16: 0,
  endUtf16: quote.length,
  role: role,
  verifiedAt: at,
);

VerifiedProofClaim _claim(
  ProofClaimKind kind,
  List<VerifiedEvidenceSnapshot> evidence,
) => VerifiedProofClaim(
  claimId: kind.name,
  kind: kind,
  text: 'statement for ${kind.name}',
  evidence: evidence,
);

ProofQualityReceipt _build(
  List<VerifiedProofClaim> claims, {
  Set<ProofClaimKind> unsupported = const {},
  DateTime? now,
  ProofQualityThresholds thresholds = const ProofQualityThresholds(),
}) => ProofQualityCalculator(thresholds: thresholds).build(
  claims: claims,
  confidenceBand: ProofConfidenceBand.medium,
  unsupportedClaims: unsupported,
  now: now ?? _now,
);

/// Evidence spread evenly across [days], one distinct source each.
List<VerifiedEvidenceSnapshot> _spread(
  List<int> days, {
  String quote = 'a specific thing happened',
}) => [
  for (var index = 0; index < days.length; index++)
    _snapshot(
      'entry-${days[index]}',
      quote,
      DateTime.utc(2026, 7).add(Duration(days: days[index])),
    ),
];

void main() {
  group('repeat frequency', () {
    test('one moment can never establish a repeat', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          _snapshot('entry-1', 'checked the numbers first', _now),
        ]),
      ]);

      expect(receipt.frequency.distinctMoments, 1);
      expect(receipt.frequency.established, isFalse);
      expect(receipt.proofType, ProofType.currentObservation);
      expect(
        receipt.missingEvidence,
        contains(MissingEvidenceReason.needsAnotherDistinctSource),
      );
    });

    test('one moment cited twice still counts once', () {
      final at = DateTime.utc(2026, 7);
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          _snapshot('entry-1', 'checked the numbers first', at),
          _snapshot('entry-1', 'and checked them again later', at),
        ]),
      ]);

      expect(receipt.frequency.distinctMoments, 1);
      expect(receipt.frequency.established, isFalse);
    });

    test('the window is reported as counts and dates, never as a rate', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 10, 20])),
      ]);

      expect(receipt.frequency.distinctMoments, 3);
      expect(receipt.frequency.windowDays, 20);
      expect(
        VerifiedProofViewModel.frequencyLineFor(receipt.frequency),
        'Seen in 3 verified moments over 20 days.',
      );
      expect(
        VerifiedProofViewModel.frequencyLineFor(receipt.frequency),
        isNot(contains('per day')),
      );
    });
  });

  group('trend', () {
    test('sparse evidence is insufficient rather than stable', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 10])),
      ]);

      expect(receipt.trend, ProofTrend.insufficientEvidence);
      expect(VerifiedProofViewModel.trendLineFor(receipt.trend), isNull);
    });

    test('more moments in the later window read as increasing', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 18, 19, 20])),
      ]);

      expect(receipt.trend, ProofTrend.increasing);
    });

    test('more moments in the earlier window read as decreasing', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 1, 2, 20])),
      ]);

      expect(receipt.trend, ProofTrend.decreasing);
    });

    test('evenly spread moments read as stable', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 5, 15, 20])),
      ]);

      expect(receipt.trend, ProofTrend.stable);
    });

    test('heavy contradiction pressure reads as mixed, not a direction', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          ..._spread([0, 18, 19, 20]),
          _snapshot(
            'entry-99',
            'that is not how it went at all',
            DateTime.utc(2026, 7, 21),
            role: ProofEvidenceRole.contradiction,
          ),
          _snapshot(
            'entry-98',
            'the opposite happened here',
            DateTime.utc(2026, 7, 22),
            role: ProofEvidenceRole.contradiction,
          ),
        ]),
      ]);

      expect(receipt.trend, ProofTrend.mixed);
      expect(receipt.proofType, ProofType.unresolved);
    });

    test('same-day moments are not comparable windows', () {
      final at = DateTime.utc(2026, 7);
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          _snapshot('entry-1', 'a specific thing happened', at),
          _snapshot('entry-2', 'another specific thing happened', at),
          _snapshot('entry-3', 'a third specific thing happened', at),
        ]),
      ]);

      expect(receipt.trend, ProofTrend.insufficientEvidence);
      expect(
        receipt.strengthOverTime,
        ProofStrengthOverTime.insufficientEvidence,
      );
    });
  });

  group('strength over time', () {
    test('longer later quotes read as stronger', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          _snapshot('entry-1', 'checked numbers', DateTime.utc(2026, 7)),
          _snapshot('entry-2', 'checked numbers', DateTime.utc(2026, 7, 5)),
          _snapshot(
            'entry-3',
            'checked every number in the report before replying to anyone',
            DateTime.utc(2026, 7, 20),
          ),
        ]),
      ]);

      expect(receipt.strengthOverTime, ProofStrengthOverTime.stronger);
    });

    test('shorter later quotes read as weaker', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          _snapshot(
            'entry-1',
            'checked every number in the report before replying to anyone',
            DateTime.utc(2026, 7),
          ),
          _snapshot(
            'entry-2',
            'checked every number in the report again',
            DateTime.utc(2026, 7, 5),
          ),
          _snapshot('entry-3', 'checked it', DateTime.utc(2026, 7, 20)),
        ]),
      ]);

      expect(receipt.strengthOverTime, ProofStrengthOverTime.weaker);
    });

    test('comparable quotes read as unchanged', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 10, 20])),
      ]);

      expect(receipt.strengthOverTime, ProofStrengthOverTime.unchanged);
    });
  });

  group('occurrences and change evidence', () {
    test('first and last come from verified sources, not generation time', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 10, 20])),
      ], now: DateTime.utc(2027));

      expect(receipt.firstOccurrence, DateTime.utc(2026, 7));
      expect(receipt.lastOccurrence, DateTime.utc(2026, 7, 21));
      expect(receipt.generatedAt, DateTime.utc(2027));
    });

    test('a change claim exposes then and now in chronological order', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0])),
        _claim(ProofClaimKind.directionOfChange, [
          _snapshot('entry-a', 'i avoided the call', DateTime.utc(2026, 7, 2)),
          _snapshot('entry-b', 'i made the call', DateTime.utc(2026, 7, 20)),
        ]),
      ]);

      expect(receipt.proofType, ProofType.change);
      expect(receipt.thenEvidence?.sourceEntryId, 'entry-a');
      expect(receipt.nowEvidence?.sourceEntryId, 'entry-b');
      expect(
        receipt.thenEvidence!.sourceDate.isBefore(
          receipt.nowEvidence!.sourceDate,
        ),
        isTrue,
      );
    });

    test('a change claim without two moments asks for then and now', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0])),
        _claim(ProofClaimKind.directionOfChange, [
          _snapshot('entry-a', 'i avoided the call', DateTime.utc(2026, 7, 2)),
        ]),
      ]);

      expect(receipt.thenEvidence, isNull);
      expect(
        receipt.missingEvidence,
        containsAll([
          MissingEvidenceReason.needsValidThenSource,
          MissingEvidenceReason.needsValidNowSource,
        ]),
      );
    });
  });

  group('counterexamples, contradictions and missing evidence', () {
    test('counterexamples are kept, never trimmed to look cleaner', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          ..._spread([0, 10, 20]),
          _snapshot(
            'entry-x',
            'i decided without looking at anything',
            DateTime.utc(2026, 7, 15),
            role: ProofEvidenceRole.counterexample,
          ),
        ]),
      ]);

      expect(receipt.counterexamples, hasLength(1));
      expect(receipt.supportingEvidence, hasLength(3));
    });

    test('a contradiction always asks to be resolved', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          ..._spread([0, 10]),
          _snapshot(
            'entry-x',
            'none of that is true',
            DateTime.utc(2026, 7, 15),
            role: ProofEvidenceRole.contradiction,
          ),
        ]),
      ]);

      expect(
        receipt.missingEvidence,
        contains(MissingEvidenceReason.needsContradictionResolution),
      );
    });

    test('a short quote asks for a more specific moment', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, [
          _snapshot('entry-1', 'i did', DateTime.utc(2026, 7)),
          _snapshot(
            'entry-2',
            'a specific thing happened',
            DateTime.utc(2026, 7, 10),
          ),
        ]),
      ]);

      expect(
        receipt.missingEvidence,
        contains(MissingEvidenceReason.needsMoreSpecificQuote),
      );
    });

    test('old evidence asks for something newer', () {
      final receipt = _build([
        _claim(ProofClaimKind.mainObservation, _spread([0, 10])),
      ], now: DateTime.utc(2027));

      expect(
        receipt.missingEvidence,
        contains(MissingEvidenceReason.needsNewerEvidence),
      );
    });

    test('missing evidence never asks for generic journalling', () {
      for (final reason in MissingEvidenceReason.values) {
        final line = VerifiedProofViewModel.missingEvidenceLineFor(reason);
        expect(line.toLowerCase(), isNot(contains('journal')));
        expect(line.toLowerCase(), isNot(contains('write more')));
      }
    });
  });

  group('determinism and serialisation', () {
    test('the same claims always produce the same receipt', () {
      final claims = [
        _claim(ProofClaimKind.mainObservation, _spread([0, 5, 15, 20])),
      ];

      expect(_build(claims).toJson(), _build(claims).toJson());
    });

    test('a receipt survives a round trip with every dimension intact', () {
      final receipt = _build(
        [
          _claim(ProofClaimKind.mainObservation, _spread([0, 18, 19, 20])),
          _claim(ProofClaimKind.directionOfChange, [
            _snapshot(
              'entry-a',
              'i avoided the call',
              DateTime.utc(2026, 7, 2),
            ),
            _snapshot('entry-b', 'i made the call', DateTime.utc(2026, 7, 20)),
          ]),
        ],
        unsupported: {ProofClaimKind.trend},
      );
      final restored = ProofQualityReceipt.fromJson(receipt.toJson());

      expect(restored.toJson(), receipt.toJson());
      expect(restored.trend, receipt.trend);
      expect(restored.unsupportedClaims, [ProofClaimKind.trend]);
      expect(restored.thenEvidence?.sourceEntryId, 'entry-a');
    });

    test('a schema 1 receipt restores as unestablished, never as a guess', () {
      final restored = ProofQualityReceipt.fromJson({
        'repeatFrequency': 4,
        'trend': 'supported',
        'confidenceBand': 'medium',
        'counterexamples': 0,
        'missingEvidence': <String>[],
        'strengthOverTime': 'comparable_windows_supported',
        'firstOccurrence': '2026-07-01T00:00:00.000Z',
        'lastOccurrence': '2026-07-21T00:00:00.000Z',
        'contradictions': 0,
        'schemaVersion': 1,
      });

      expect(restored.trend, ProofTrend.insufficientEvidence);
      expect(
        restored.strengthOverTime,
        ProofStrengthOverTime.insufficientEvidence,
      );
      expect(restored.frequency.established, isFalse);
    });
  });

  group('presentation', () {
    test('no dimension is ever rendered as a number or a percentage', () {
      final lines = [
        for (final trend in ProofTrend.values)
          VerifiedProofViewModel.trendLineFor(trend),
        for (final strength in ProofStrengthOverTime.values)
          VerifiedProofViewModel.strengthLineFor(strength),
        for (final band in ProofConfidenceBand.values)
          VerifiedProofViewModel.confidenceLabelFor(band),
      ].nonNulls;

      for (final line in lines) {
        expect(line, isNot(contains('%')));
        expect(line, isNot(matches(RegExp(r'\d'))));
      }
    });

    test('unestablished dimensions produce no line at all', () {
      expect(
        VerifiedProofViewModel.trendLineFor(ProofTrend.insufficientEvidence),
        isNull,
      );
      expect(
        VerifiedProofViewModel.strengthLineFor(
          ProofStrengthOverTime.insufficientEvidence,
        ),
        isNull,
      );
      expect(
        VerifiedProofViewModel.frequencyLineFor(const ProofFrequency.none()),
        isNull,
      );
    });
  });
}