/// Scores the candidate conclusions produced by `generate_candidates.dart`.
///
/// Precision is weighted above recall throughout: a refusal to conclude costs
/// recall, an unsupported claim costs precision, and only the precision-shaped
/// metrics are enforced by default.
///
/// Run from `apps/voicememory_mobile`:
///   dart run tool/conclusion_evaluation/generate_candidates.dart
///   dart run tool/conclusion_evaluation/score_evaluation.dart
library;

import 'dart:convert';
import 'dart:io';

const defaultCandidateInput = 'build/conclusion_evaluation/candidates.json';
const defaultScoreOutput = 'build/conclusion_evaluation/scores.json';
const defaultThresholdFile = 'tool/conclusion_evaluation/thresholds.json';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final input = File(options.input);
  if (!input.existsSync()) {
    stderr.writeln('Candidate file not found: ${options.input}');
    stderr.writeln(
      'Run: dart run tool/conclusion_evaluation/generate_candidates.dart',
    );
    exitCode = 2;
    return;
  }
  final payload = Map<String, dynamic>.from(
    jsonDecode(input.readAsStringSync()) as Map,
  );
  final records = (payload['records'] as List)
      .map((record) => Map<String, dynamic>.from(record as Map))
      .toList(growable: false);
  final thresholds = _readThresholds(options.thresholds);

  final scored = score(records);
  final checks = evaluateThresholds(scored.metrics, thresholds);

  _printReport(scored, checks, thresholds, options);

  final output = File(options.output);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'scoredAt': DateTime.now().toUtc().toIso8601String(),
      'candidateFile': options.input,
      'thresholdFile': options.thresholds,
      'dataProvenance': 'synthetic',
      'humanLabelledCaseCount': scored.humanLabelledCount,
      'caseCount': records.length,
      'metrics': {for (final entry in scored.metrics.entries) entry.key: entry.value.toJson()},
      'thresholdChecks': checks.map((check) => check.toJson()).toList(),
      'failures': scored.failures,
      'breakdown': scored.breakdown,
    })}\n',
  );
  stdout.writeln('Scores written to ${options.output}');

  final breached = checks.where((check) => check.enforced && !check.passed);
  if (options.enforce && breached.isNotEmpty) {
    stderr.writeln(
      'Enforced thresholds breached: '
      '${breached.map((check) => check.metric).join(', ')}',
    );
    exitCode = 1;
  }
}

/// A ratio plus the counts it came from, so no number is readable without the
/// evidence behind it.
class Metric {
  const Metric({
    required this.name,
    required this.numerator,
    required this.denominator,
    required this.description,
    this.higherIsBetter = true,
  });

  final String name;
  final int numerator;
  final int denominator;
  final String description;
  final bool higherIsBetter;

  /// Null when nothing in the fixture set exercises this metric.
  double? get value => denominator == 0 ? null : numerator / denominator;

  Map<String, dynamic> toJson() => {
    'value': value,
    'numerator': numerator,
    'denominator': denominator,
    'higherIsBetter': higherIsBetter,
    'description': description,
  };
}

class ThresholdCheck {
  const ThresholdCheck({
    required this.metric,
    required this.bound,
    required this.isMinimum,
    required this.actual,
    required this.enforced,
  });

  final String metric;
  final double bound;
  final bool isMinimum;
  final double? actual;
  final bool enforced;

  bool get passed {
    final observed = actual;
    if (observed == null) return true;
    return isMinimum ? observed >= bound : observed <= bound;
  }

  Map<String, dynamic> toJson() => {
    'metric': metric,
    'bound': bound,
    'direction': isMinimum ? 'min' : 'max',
    'actual': actual,
    'enforced': enforced,
    'passed': passed,
  };
}

class ScoreResult {
  const ScoreResult({
    required this.metrics,
    required this.failures,
    required this.breakdown,
    required this.humanLabelledCount,
  });

  final Map<String, Metric> metrics;
  final List<Map<String, dynamic>> failures;
  final Map<String, dynamic> breakdown;
  final int humanLabelledCount;
}

ScoreResult score(List<Map<String, dynamic>> records) {
  var relatedTruePositive = 0;
  var relatedFalsePositive = 0;
  var relatedFalseNegative = 0;

  var emittedCount = 0;
  var kindCorrect = 0;
  var genericOutputs = 0;
  var exactEvidenceValid = 0;

  var changeCases = 0;
  var changeEmitted = 0;

  var dimensionCases = 0;
  var dimensionExactMatches = 0;
  var directionComparisons = 0;
  var directionMatches = 0;

  var prohibitedProbes = 0;
  var prohibitedAccepted = 0;
  var wrongDomainProbes = 0;
  var wrongDomainAccepted = 0;

  var supportedProbes = 0;
  var supportedAccepted = 0;

  var suppressionExpected = 0;
  var suppressionReasonMatched = 0;

  var suppressedCases = 0;
  var humanLabelled = 0;

  final failures = <Map<String, dynamic>>[];
  final byDomain = <String, int>{};
  final byDifficulty = <String, int>{};

  for (final record in records) {
    final caseId = record['caseId'] as String;
    final expected = Map<String, dynamic>.from(record['expected'] as Map);
    final actual = Map<String, dynamic>.from(record['actual'] as Map);
    final isPair = record['isPair'] == true;
    final reasons = <String>[];

    byDomain.update(
      record['sourceDomain'] as String,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    byDifficulty.update(
      record['difficulty'] as String,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    if (record['humanLabelStatus'] == 'humanLabelled') humanLabelled++;

    if (isPair) {
      final relatedExpected = expected['relatedExpected'] == true;
      final relatedActual = actual['relatedByEngine'] == true;
      if (relatedActual && relatedExpected) relatedTruePositive++;
      if (relatedActual && !relatedExpected) {
        relatedFalsePositive++;
        reasons.add(
          'related-pair FALSE POSITIVE: engine paired two moments a reader '
          'would not call the same subject',
        );
      }
      if (!relatedActual && relatedExpected) {
        relatedFalseNegative++;
        reasons.add(
          'related-pair miss: engine refused to pair two genuinely related '
          'moments',
        );
      }
    }

    final expectedKind = expected['expectedKind'] as String;
    final emitted = actual['emitted'] == true;
    if (!emitted) suppressedCases++;
    if (expectedKind == 'change') {
      changeCases++;
      if (emitted) changeEmitted++;
    }

    if (emitted) {
      emittedCount++;
      final emittedKind = actual['emittedKind'] as String?;
      final kindMatches = expectedKind == 'change' && emittedKind == 'change';
      if (kindMatches) {
        kindCorrect++;
      } else {
        reasons.add(
          'conclusion-kind error: engine emitted "$emittedKind" where the '
          'evidence supports "$expectedKind"',
        );
      }
      if (actual['genericOutput'] == true) {
        genericOutputs++;
        reasons.add('generic output: statement says nothing specific');
      }
      if (actual['exactEvidenceValid'] == true) {
        exactEvidenceValid++;
      } else {
        reasons.add('exact-evidence failure: a citation did not resolve');
      }
    }

    final expectedDimensions =
        ((expected['expectedChangedDimensions'] as List?)?.cast<String>() ??
        const <String>[]);
    final detectedDimensions =
        ((actual['detectedChangedDimensions'] as List?)?.cast<String>() ??
        const <String>[]);
    // Only cases that should carry a change, or that produced one, are scored
    // on dimensions. A correctly silent case reads dimensions internally
    // without ever claiming them, so grading it here would measure nothing.
    if (isPair && (expectedKind == 'change' || emitted)) {
      dimensionCases++;
      final expectedNames = _names(expectedDimensions);
      final detectedNames = _names(detectedDimensions);
      if (_sameSet(expectedNames, detectedNames)) {
        dimensionExactMatches++;
      } else {
        reasons.add(
          'dimension mismatch: expected {${expectedNames.join(', ')}}, '
          'engine read {${detectedNames.join(', ')}}',
        );
      }
      final expectedByName = _directions(expectedDimensions);
      final detectedByName = _directions(detectedDimensions);
      for (final name in expectedByName.keys) {
        final detected = detectedByName[name];
        if (detected == null) continue;
        directionComparisons++;
        if (detected == expectedByName[name]) {
          directionMatches++;
        } else {
          reasons.add(
            'direction error on $name: expected ${expectedByName[name]}, '
            'engine read $detected',
          );
        }
      }
    }

    for (final raw in (actual['prohibitedProbes'] as List)) {
      final probe = Map<String, dynamic>.from(raw as Map);
      prohibitedProbes++;
      final accepted = probe['accepted'] == true;
      final isWrongDomain = probe['violation'] == 'wrongDomain';
      if (isWrongDomain) wrongDomainProbes++;
      if (accepted) {
        prohibitedAccepted++;
        if (isWrongDomain) wrongDomainAccepted++;
        reasons.add(
          'unsupported claim ACCEPTED (${probe['violation']}): '
          '"${probe['statement']}"',
        );
      }
    }

    final supportedProbe = Map<String, dynamic>.from(
      actual['supportedProbe'] as Map,
    );
    final expectedSuppression =
        expected['expectedSuppressionReason'] as String?;
    if (expectedSuppression == null &&
        expected['supportedConclusion'] != null) {
      supportedProbes++;
      if (supportedProbe['accepted'] == true) {
        supportedAccepted++;
      } else {
        reasons.add(
          'supported conclusion REJECTED by the gate: '
          '${(supportedProbe['rejections'] as List).join(', ')}',
        );
      }
    }
    if (expectedSuppression != null) {
      suppressionExpected++;
      final rejections = (supportedProbe['rejections'] as List).cast<String>();
      if (rejections.contains(expectedSuppression)) {
        suppressionReasonMatched++;
      } else {
        reasons.add(
          'suppression-reason mismatch: expected $expectedSuppression, '
          'gate gave {${rejections.join(', ')}}',
        );
      }
      if (emitted) {
        reasons.add(
          'SUPPRESSION FAILURE: engine emitted a conclusion for a case that '
          'must produce nothing',
        );
      }
    }
    if (expectedSuppression == null && expectedKind == 'change' && !emitted) {
      reasons.add(
        'missed change: engine produced nothing for a supportable change',
      );
    }

    if (reasons.isNotEmpty) {
      failures.add({
        'caseId': caseId,
        'sourceDomain': record['sourceDomain'],
        'difficulty': record['difficulty'],
        'reasons': reasons,
      });
    }
  }

  final metrics = <String, Metric>{
    'relatedPairPrecision': Metric(
      name: 'relatedPairPrecision',
      numerator: relatedTruePositive,
      denominator: relatedTruePositive + relatedFalsePositive,
      description:
          'Of the pairs the engine treated as the same subject, how many a '
          'reader would agree about.',
    ),
    'relatedPairRecall': Metric(
      name: 'relatedPairRecall',
      numerator: relatedTruePositive,
      denominator: relatedTruePositive + relatedFalseNegative,
      description:
          'Of the genuinely related pairs, how many the engine was willing to '
          'compare.',
    ),
    'conclusionKindPrecision': Metric(
      name: 'conclusionKindPrecision',
      numerator: kindCorrect,
      denominator: emittedCount,
      description:
          'Of the conclusions actually shown, how many claim a kind the '
          'evidence supports.',
    ),
    'changeDirectionAccuracy': Metric(
      name: 'changeDirectionAccuracy',
      numerator: directionMatches,
      denominator: directionComparisons,
      description:
          'Of the dimensions both the label and the engine identified, how '
          'many moved in the same direction.',
    ),
    'dimensionAccuracy': Metric(
      name: 'dimensionAccuracy',
      numerator: dimensionExactMatches,
      denominator: dimensionCases,
      description:
          'Cases where the engine read exactly the set of moved dimensions the '
          'label expects.',
    ),
    'unsupportedClaimRate': Metric(
      name: 'unsupportedClaimRate',
      numerator: prohibitedAccepted,
      denominator: prohibitedProbes,
      description:
          'Prohibited statements the semantic gate let through. Lower is '
          'better.',
      higherIsBetter: false,
    ),
    'wrongDomainRate': Metric(
      name: 'wrongDomainRate',
      numerator: wrongDomainAccepted,
      denominator: wrongDomainProbes,
      description:
          'Cross-domain statements the semantic gate let through. Lower is '
          'better.',
      higherIsBetter: false,
    ),
    'genericOutputRate': Metric(
      name: 'genericOutputRate',
      numerator: genericOutputs,
      denominator: emittedCount,
      description:
          'Emitted conclusions that say nothing specific to their evidence. '
          'Lower is better.',
      higherIsBetter: false,
    ),
    'suppressionRate': Metric(
      name: 'suppressionRate',
      numerator: suppressedCases,
      denominator: records.length,
      description:
          'Cases where the engine produced no conclusion. Informational: '
          'silence is a valid outcome.',
      higherIsBetter: false,
    ),
    'exactEvidenceValidity': Metric(
      name: 'exactEvidenceValidity',
      numerator: exactEvidenceValid,
      denominator: emittedCount,
      description:
          'Emitted conclusions whose every citation resolves to the exact '
          'transcript span it claims.',
    ),
    'supportedConclusionAcceptance': Metric(
      name: 'supportedConclusionAcceptance',
      numerator: supportedAccepted,
      denominator: supportedProbes,
      description: 'Genuinely supported statements the semantic gate accepted.',
    ),
    'suppressionReasonMatch': Metric(
      name: 'suppressionReasonMatch',
      numerator: suppressionReasonMatched,
      denominator: suppressionExpected,
      description: 'Suppressed cases refused for the reason the label expects.',
    ),
    'changeEmissionRate': Metric(
      name: 'changeEmissionRate',
      numerator: changeEmitted,
      denominator: changeCases,
      description:
          'Cases labelled as a supportable change where the engine produced '
          'one. Informational recall figure.',
    ),
  };

  return ScoreResult(
    metrics: metrics,
    failures: failures,
    breakdown: {'bySourceDomain': byDomain, 'byDifficulty': byDifficulty},
    humanLabelledCount: humanLabelled,
  );
}

List<ThresholdCheck> evaluateThresholds(
  Map<String, Metric> metrics,
  Map<String, dynamic> thresholds,
) {
  final checks = <ThresholdCheck>[];
  void add(String key, Object? bound, {required bool enforced}) {
    if (bound is! num) return;
    final isMinimum = key.startsWith('min');
    final metricName = _metricNameFor(key);
    final metric = metrics[metricName];
    if (metric == null) return;
    checks.add(
      ThresholdCheck(
        metric: metricName,
        bound: bound.toDouble(),
        isMinimum: isMinimum,
        actual: metric.value,
        enforced: enforced,
      ),
    );
  }

  final enforced = Map<String, dynamic>.from(
    (thresholds['enforced'] as Map?) ?? const {},
  );
  final advisory = Map<String, dynamic>.from(
    (thresholds['advisory'] as Map?) ?? const {},
  );
  for (final entry in enforced.entries) {
    add(entry.key, entry.value, enforced: true);
  }
  for (final entry in advisory.entries) {
    add(entry.key, entry.value, enforced: false);
  }
  return checks;
}

String _metricNameFor(String thresholdKey) {
  final stripped = thresholdKey.replaceFirst(RegExp('^(min|max)'), '');
  return stripped.isEmpty
      ? thresholdKey
      : '${stripped[0].toLowerCase()}${stripped.substring(1)}';
}

Set<String> _names(List<String> pairs) =>
    pairs.map((pair) => pair.split(':').first).toSet();

Map<String, String> _directions(List<String> pairs) => {
  for (final pair in pairs)
    if (pair.contains(':')) pair.split(':').first: pair.split(':').last,
};

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

Map<String, dynamic> _readThresholds(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

void _printReport(
  ScoreResult scored,
  List<ThresholdCheck> checks,
  Map<String, dynamic> thresholds,
  _Options options,
) {
  stdout.writeln('');
  stdout.writeln('ArchiveMe conclusion evaluation — SYNTHETIC fixtures only');
  stdout.writeln('Human-labelled cases: ${scored.humanLabelledCount}');
  stdout.writeln('');
  stdout.writeln('METRIC                          VALUE     N        BOUND');
  final checkByMetric = {for (final check in checks) check.metric: check};
  for (final metric in scored.metrics.values) {
    final check = checkByMetric[metric.name];
    final value = metric.value;
    final rendered = value == null
        ? 'n/a  '
        : value.toStringAsFixed(3).padRight(5);
    final bound = check == null
        ? '—'
        : '${check.isMinimum ? '>=' : '<='} ${check.bound} '
              '${check.passed ? 'PASS' : 'FAIL'}'
              '${check.enforced ? '' : ' (advisory)'}';
    stdout.writeln(
      '${metric.name.padRight(31)} $rendered    '
      '${'${metric.numerator}/${metric.denominator}'.padRight(8)} $bound',
    );
  }

  stdout.writeln('');
  stdout.writeln('Cases with at least one failure: ${scored.failures.length}');
  for (final failure in scored.failures) {
    stdout.writeln('  ${failure['caseId']}');
    for (final reason in failure['reasons'] as List) {
      stdout.writeln('    - $reason');
    }
  }
  stdout.writeln('');
  stdout.writeln('Breakdown: ${jsonEncode(scored.breakdown)}');
}

class _Options {
  const _Options({
    required this.input,
    required this.output,
    required this.thresholds,
    required this.enforce,
  });

  factory _Options.parse(List<String> args) {
    var input = defaultCandidateInput;
    var output = defaultScoreOutput;
    var thresholds = defaultThresholdFile;
    var enforce = false;
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--in' && index + 1 < args.length) {
        input = args[++index];
      } else if (arg.startsWith('--in=')) {
        input = arg.substring('--in='.length);
      } else if (arg == '--out' && index + 1 < args.length) {
        output = args[++index];
      } else if (arg.startsWith('--out=')) {
        output = arg.substring('--out='.length);
      } else if (arg == '--thresholds' && index + 1 < args.length) {
        thresholds = args[++index];
      } else if (arg.startsWith('--thresholds=')) {
        thresholds = arg.substring('--thresholds='.length);
      } else if (arg == '--enforce') {
        enforce = true;
      }
    }
    return _Options(
      input: input,
      output: output,
      thresholds: thresholds,
      enforce: enforce,
    );
  }

  final String input;
  final String output;
  final String thresholds;
  final bool enforce;
}
