import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/calibration_report.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';

void main() {
  CalibrationSample sample({
    CalibrationCohort cohort = CalibrationCohort.syntheticFixture,
    ProofAdmissionOutcome outcome = ProofAdmissionOutcome.admitted,
    ArchiveCorrectionChoice? choice,
    ProofConfidenceBand? band,
    ProofClaimKind? claimKind,
    int sources = 1,
    int contradictions = 0,
  }) => CalibrationSample(
    cohort: cohort,
    outcome: outcome,
    choice: choice,
    band: band,
    claimKind: claimKind,
    distinctSourceCount: sources,
    contradictionCount: contradictions,
  );

  List<CalibrationSample> many(
    int count, {
    CalibrationCohort cohort = CalibrationCohort.syntheticFixture,
    ArchiveCorrectionChoice? choice,
    ProofConfidenceBand? band,
  }) => List.generate(
    count,
    (_) => sample(cohort: cohort, choice: choice, band: band),
  );

  group('cohort separation', () {
    test('samples from another cohort are dropped, not merged', () {
      final report =
          CalibrationReport.forCohort(CalibrationCohort.consentedRealUser, [
            ...many(20, cohort: CalibrationCohort.consentedRealUser),
            ...many(50, cohort: CalibrationCohort.syntheticFixture),
          ]);

      expect(report.sampleCount, 20);
      expect(report.cohort, CalibrationCohort.consentedRealUser);
    });

    test('each cohort reports its own rate', () {
      final samples = [
        ...many(
          20,
          cohort: CalibrationCohort.syntheticFixture,
          choice: ArchiveCorrectionChoice.exactlyRight,
        ),
        ...many(
          20,
          cohort: CalibrationCohort.consentedRealUser,
          choice: ArchiveCorrectionChoice.wrong,
        ),
      ];

      final synthetic = CalibrationReport.forCohort(
        CalibrationCohort.syntheticFixture,
        samples,
      );
      final real = CalibrationReport.forCohort(
        CalibrationCohort.consentedRealUser,
        samples,
      );

      expect(synthetic.rateFor(ArchiveCorrectionChoice.exactlyRight), 1.0);
      expect(real.rateFor(ArchiveCorrectionChoice.exactlyRight), 0.0);
      expect(real.rateFor(ArchiveCorrectionChoice.wrong), 1.0);
    });
  });

  group('small samples', () {
    test('a small cohort reports no rates at all', () {
      final report = CalibrationReport.forCohort(
        CalibrationCohort.consentedRealUser,
        many(
          4,
          cohort: CalibrationCohort.consentedRealUser,
          choice: ArchiveCorrectionChoice.wrong,
        ),
      );

      expect(report.isReportable, isFalse);
      expect(report.rateFor(ArchiveCorrectionChoice.wrong), isNull);
      expect(report.suppressionRate, isNull);
      expect(report.contradictionRate, isNull);
    });

    test('the threshold is where reporting begins', () {
      final report = CalibrationReport.forCohort(
        CalibrationCohort.syntheticFixture,
        many(
          CalibrationReport.minimumSampleSize,
          choice: ArchiveCorrectionChoice.wrong,
        ),
      );

      expect(report.isReportable, isTrue);
      expect(report.rateFor(ArchiveCorrectionChoice.wrong), 1.0);
    });

    test('an uncorrected cohort has no choice rates', () {
      final report = CalibrationReport.forCohort(
        CalibrationCohort.syntheticFixture,
        many(30),
      );

      expect(report.correctedCount, 0);
      expect(report.rateFor(ArchiveCorrectionChoice.exactlyRight), isNull);
    });
  });

  group('rates', () {
    test('choice rates are shares of corrected proofs', () {
      final report =
          CalibrationReport.forCohort(CalibrationCohort.syntheticFixture, [
            ...many(10, choice: ArchiveCorrectionChoice.exactlyRight),
            ...many(10, choice: ArchiveCorrectionChoice.wrong),
            ...many(10),
          ]);

      expect(report.correctedCount, 20);
      expect(report.rateFor(ArchiveCorrectionChoice.exactlyRight), 0.5);
      expect(report.rateFor(ArchiveCorrectionChoice.wrong), 0.5);
      expect(report.rateFor(ArchiveCorrectionChoice.partlyRight), 0.0);
    });

    test('outcome rates are shares of all samples', () {
      final report =
          CalibrationReport.forCohort(CalibrationCohort.syntheticFixture, [
            ...List.generate(
              5,
              (_) => sample(outcome: ProofAdmissionOutcome.invalidEvidence),
            ),
            ...List.generate(15, (_) => sample()),
          ]);

      expect(report.invalidEvidenceRate, 0.25);
    });

    test('contradiction rate counts only admitted proofs', () {
      final report =
          CalibrationReport.forCohort(CalibrationCohort.syntheticFixture, [
            ...List.generate(5, (_) => sample(contradictions: 2)),
            ...List.generate(5, (_) => sample()),
            ...List.generate(
              10,
              (_) => sample(
                outcome: ProofAdmissionOutcome.suppressed,
                contradictions: 9,
              ),
            ),
          ]);

      expect(report.contradictionRate, 0.5);
    });

    test('acceptance is broken out by confidence band', () {
      final report =
          CalibrationReport.forCohort(CalibrationCohort.syntheticFixture, [
            ...many(
              10,
              band: ProofConfidenceBand.high,
              choice: ArchiveCorrectionChoice.exactlyRight,
            ),
            ...many(
              10,
              band: ProofConfidenceBand.low,
              choice: ArchiveCorrectionChoice.wrong,
            ),
          ]);

      expect(report.acceptanceByBand[ProofConfidenceBand.high], 1.0);
      expect(report.acceptanceByBand[ProofConfidenceBand.low], 0.0);
    });

    test('acceptance is broken out by source count band', () {
      final report =
          CalibrationReport.forCohort(CalibrationCohort.syntheticFixture, [
            ...List.generate(
              10,
              (_) => sample(sources: 1, choice: ArchiveCorrectionChoice.wrong),
            ),
            ...List.generate(
              10,
              (_) => sample(
                sources: 3,
                choice: ArchiveCorrectionChoice.exactlyRight,
              ),
            ),
          ]);

      expect(report.acceptanceBySourceCount['single'], 0.0);
      expect(report.acceptanceBySourceCount['few'], 1.0);
    });

    test('acceptance is broken out by claim kind', () {
      final report =
          CalibrationReport.forCohort(CalibrationCohort.syntheticFixture, [
            ...List.generate(
              10,
              (_) => sample(
                claimKind: ProofClaimKind.repeated,
                choice: ArchiveCorrectionChoice.exactlyRight,
              ),
            ),
            ...List.generate(
              10,
              (_) => sample(
                claimKind: ProofClaimKind.mainObservation,
                choice: ArchiveCorrectionChoice.partlyRight,
              ),
            ),
          ]);

      expect(report.acceptanceByClaimKind[ProofClaimKind.repeated], 1.0);
      expect(report.acceptanceByClaimKind[ProofClaimKind.mainObservation], 0.0);
    });
  });

  group('privacy', () {
    test('the report carries no free text of any kind', () {
      final report = CalibrationReport.forCohort(
        CalibrationCohort.consentedRealUser,
        many(
          25,
          cohort: CalibrationCohort.consentedRealUser,
          choice: ArchiveCorrectionChoice.exactlyRight,
          band: ProofConfidenceBand.high,
        ),
      );

      final encoded = jsonEncode(report.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      // Every leaf is a name from a closed set, a number, a bool or null.
      void assertStructural(dynamic value) {
        if (value == null || value is num || value is bool) return;
        if (value is String) {
          final allowed = {
            ...CalibrationCohort.values.map((item) => item.name),
            ...ArchiveCorrectionChoice.values.map((item) => item.name),
            ...ProofConfidenceBand.values.map((item) => item.name),
            ...ProofClaimKind.values.map((item) => item.name),
            'none',
            'single',
            'few',
            'many',
          };
          expect(allowed, contains(value));
          return;
        }
        if (value is Map) {
          for (final entry in value.entries) {
            assertStructural(entry.value);
          }
          return;
        }
        if (value is List) {
          value.forEach(assertStructural);
          return;
        }
        fail('unexpected leaf type ${value.runtimeType}');
      }

      for (final entry in decoded.entries) {
        assertStructural(entry.value);
      }
    });

    test('source counts are reported as bands, never as exact numbers', () {
      final report = CalibrationReport.forCohort(
        CalibrationCohort.consentedRealUser,
        List.generate(
          25,
          (index) => sample(
            cohort: CalibrationCohort.consentedRealUser,
            sources: index,
            choice: ArchiveCorrectionChoice.exactlyRight,
          ),
        ),
      );

      expect(
        report.acceptanceBySourceCount.keys,
        everyElement(isIn(['none', 'single', 'few', 'many'])),
      );
    });
  });
}
