@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/conclusion_evaluation/generate_candidates.dart' as harness;
import '../tool/conclusion_evaluation/score_evaluation.dart' as scoring;

/// Guards the evaluation harness itself, not the engine it measures.
///
/// The engine's own behaviour is reported in CONCLUSION_EVALUATION_REPORT.md,
/// including the cases it currently fails. What must not drift is the harness:
/// it has to keep loading every fixture, keep running the real pipeline, and
/// keep telling the truth about where its data came from.
void main() {
  final fixtures = Directory('tool/conclusion_evaluation/fixtures');
  final humanLabels = Directory('tool/conclusion_evaluation/human_labels');

  late List<Map<String, dynamic>> cases;
  late List<Map<String, dynamic>> records;
  late scoring.ScoreResult scored;

  setUpAll(() {
    cases = harness.loadFixtureCases(fixtures);
    records = harness.runHarness(cases);
    scored = scoring.score(records);
  });

  group('fixture set', () {
    test('carries meaningful coverage with unique ids', () {
      expect(cases.length, greaterThanOrEqualTo(40));
      final ids = cases.map((item) => item['caseId']).toSet();
      expect(ids.length, cases.length);
    });

    test('every case declares the full schema record', () {
      const required = {
        'caseId',
        'entryA',
        'entryB',
        'relatedExpected',
        'expectedKind',
        'expectedChangedDimensions',
        'supportedConclusion',
        'prohibitedConclusions',
        'expectedSuppressionReason',
        'sourceDomain',
        'difficulty',
        'humanLabelStatus',
      };
      for (final item in cases) {
        expect(
          item.keys.toSet().containsAll(required),
          isTrue,
          reason: '${item['caseId']} is missing schema fields',
        );
        expect(const {
          'observation',
          'repeat',
          'change',
          'neither',
        }, contains(item['expectedKind']));
      }
    });

    test('covers every named source domain and difficulty', () {
      final domains = cases.map((item) => item['sourceDomain']).toSet();
      expect(
        domains,
        containsAll(<String>{
          'work',
          'relationships',
          'money',
          'health',
          'overchecking',
          'avoidance',
          'completion',
          'askingForHelp',
          'mixed',
        }),
      );
      expect(
        cases.map((item) => item['difficulty']).toSet(),
        containsAll(<String>{'easy', 'medium', 'hard'}),
      );
    });

    test('is never described as human-validated', () {
      for (final item in cases) {
        expect(
          item['humanLabelStatus'],
          'unlabelled',
          reason: '${item['caseId']} claims a label status it has not earned',
        );
      }
      expect(scored.humanLabelledCount, 0);
    });

    test('health language carries no diagnosis wording', () {
      final diagnosis = RegExp(
        r'\b(?:diagnos(?:is|ed)|disorder|syndrome|condition)\b',
        caseSensitive: false,
      );
      for (final item in cases) {
        for (final key in const ['entryA', 'entryB']) {
          final entry = item[key];
          if (entry == null) continue;
          expect(
            diagnosis.hasMatch((entry as Map)['transcript'] as String),
            isFalse,
            reason: '${item['caseId']} $key uses diagnosis language',
          );
        }
      }
    });
  });

  group('human_labels', () {
    test('holds documentation and no label data yet', () {
      expect(humanLabels.existsSync(), isTrue);
      final dataFiles = humanLabels
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList(growable: false);
      expect(
        dataFiles,
        isEmpty,
        reason:
            'A label file appeared. Update CONCLUSION_EVALUATION_REPORT.md so '
            'it stops saying there are none.',
      );
      expect(
        File('${humanLabels.path}/README.md').readAsStringSync(),
        contains('CURRENTLY EMPTY'),
      );
    });
  });

  group('harness run', () {
    test('produces one record per case through the real pipeline', () {
      expect(records.length, cases.length);
      for (final record in records) {
        final actual = record['actual'] as Map;
        expect(actual['supportedProbe'], isA<Map>());
        expect(actual['prohibitedProbes'], isA<List>());
        expect(const {'engine', 'reader'}, contains(actual['dimensionSource']));
      }
    });

    test('an emitted conclusion always cites an exact transcript span', () {
      final validity = scored.metrics['exactEvidenceValidity']!;
      expect(validity.denominator, greaterThan(0));
      expect(validity.value, 1.0);
    });

    test('no prohibited statement reaches the semantic gate as accepted', () {
      final unsupported = scored.metrics['unsupportedClaimRate']!;
      expect(unsupported.denominator, greaterThan(0));
      expect(unsupported.value, 0.0);
      expect(scored.metrics['wrongDomainRate']!.value, anyOf(isNull, 0.0));
      expect(scored.metrics['genericOutputRate']!.value, 0.0);
    });

    test('reports failures rather than a clean sheet', () {
      // A harness that reports 100% on a set this small is not measuring
      // anything. If this ever passes trivially, the fixtures got easier.
      expect(scored.failures, isNotEmpty);
    });

    test('every scored metric names the population it came from', () {
      for (final metric in scored.metrics.values) {
        expect(metric.description, isNotEmpty);
        expect(metric.denominator, greaterThanOrEqualTo(0));
        if (metric.denominator == 0) {
          expect(metric.value, isNull);
        }
      }
    });
  });

  group('thresholds', () {
    test('every configured bound maps to a metric the harness computes', () {
      final config =
          jsonDecode(
                File(
                  'tool/conclusion_evaluation/thresholds.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final checks = scoring.evaluateThresholds(scored.metrics, config);
      final configured =
          ((config['enforced'] as Map).length +
          (config['advisory'] as Map).length);
      expect(checks.length, configured);
      for (final check in checks) {
        expect(scored.metrics.containsKey(check.metric), isTrue);
      }
    });

    test('claim-safety bounds are enforced and recall bounds are not', () {
      final config =
          jsonDecode(
                File(
                  'tool/conclusion_evaluation/thresholds.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final checks = {
        for (final check in scoring.evaluateThresholds(scored.metrics, config))
          check.metric: check,
      };
      expect(checks['unsupportedClaimRate']!.enforced, isTrue);
      expect(checks['exactEvidenceValidity']!.enforced, isTrue);
      expect(checks['relatedPairRecall']!.enforced, isFalse);
      expect(
        checks['relatedPairPrecision']!.bound,
        greaterThan(checks['relatedPairRecall']!.bound),
      );
    });
  });
}
