import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/generated/proof_admission_weights.g.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_config.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_candidate.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_candidate_scorer.dart';

ProofFeatureVector _features({
  double coverage = 0.5,
  double specificity = 0.5,
  int citationCount = 2,
  int sourceCount = 2,
  double chronology = 0.5,
  double sourceDiversity = 0.5,
  double citationSourceRatio = 0.5,
  double corroborationRatio = 0.5,
  double contradiction = 0,
  double recency = 0.5,
  double freshness = 0.5,
  double transcriptSpecificity = 0.5,
  bool userConfirmed = false,
  int correctionHistoryCount = 0,
  double acceptedCorrectionRatio = 0,
  int positiveCorrectionHistory = 0,
  int negativeCorrectionHistory = 0,
  int wordingRejectionHistory = 0,
  int evidenceRejectionHistory = 0,
  bool oneEntryPenalty = false,
  bool stalePenalty = false,
  double modelConfidence = 0.5,
  double deterministicFallback = 0,
}) => ProofFeatureVector(
  coverage: coverage,
  specificity: specificity,
  citationCount: citationCount,
  sourceCount: sourceCount,
  chronology: chronology,
  sourceDiversity: sourceDiversity,
  citationSourceRatio: citationSourceRatio,
  corroborationRatio: corroborationRatio,
  contradiction: contradiction,
  recency: recency,
  freshness: freshness,
  transcriptSpecificity: transcriptSpecificity,
  userConfirmed: userConfirmed,
  correctionHistoryCount: correctionHistoryCount,
  acceptedCorrectionRatio: acceptedCorrectionRatio,
  positiveCorrectionHistory: positiveCorrectionHistory,
  negativeCorrectionHistory: negativeCorrectionHistory,
  wordingRejectionHistory: wordingRejectionHistory,
  evidenceRejectionHistory: evidenceRejectionHistory,
  oneEntryPenalty: oneEntryPenalty,
  stalePenalty: stalePenalty,
  modelConfidence: modelConfidence,
  deterministicFallback: deterministicFallback,
);

ProofCandidate _candidate(
  String id, {
  bool hardSafetyPassed = true,
  bool isValid = true,
  ProofFeatureVector? features,
}) => ProofCandidate(
  stableId: id,
  isValid: isValid,
  hardSafetyPassed: hardSafetyPassed,
  features: features ?? _features(),
);

Map<String, dynamic> _baseConfigJson() =>
    jsonDecode(generatedProofAdmissionConfigJson) as Map<String, dynamic>;

void main() {
  group('generated weights adapter', () {
    test('stays in sync with the checked-in config file', () {
      final source = File('config/proof_admission_weights.v1.json');
      expect(source.existsSync(), isTrue);
      final onDisk = jsonDecode(source.readAsStringSync());
      expect(jsonDecode(generatedProofAdmissionConfigJson), onDisk);
    });

    test('exposes the validated config with every required weight', () {
      expect(
        generatedProofAdmissionConfig.schema,
        ProofAdmissionConfig.schemaName,
      );
      expect(
        generatedProofAdmissionConfig.version,
        ProofAdmissionConfig.supportedVersion,
      );
      expect(
        generatedProofAdmissionConfig.weights.keys.toSet(),
        ProofAdmissionConfig.requiredWeightKeys,
      );
      expect(
        generatedProofAdmissionConfig.modelConfidenceCap,
        inInclusiveRange(0, 1),
      );
    });
  });

  group('config validation', () {
    test('rejects unknown, missing, and out-of-range values', () {
      final unknownKey = _baseConfigJson()
        ..['weights'] = {
          ...(_baseConfigJson()['weights'] as Map<String, dynamic>),
          'unexpected': 1.0,
        };
      expect(
        () => ProofAdmissionConfig.fromJson(unknownKey),
        throwsFormatException,
      );

      final missingKey = _baseConfigJson();
      (missingKey['weights'] as Map<String, dynamic>).remove('coverage');
      expect(
        () => ProofAdmissionConfig.fromJson(missingKey),
        throwsFormatException,
      );

      final outOfRange = _baseConfigJson();
      (outOfRange['weights'] as Map<String, dynamic>)['coverage'] = 12.0;
      expect(
        () => ProofAdmissionConfig.fromJson(outOfRange),
        throwsFormatException,
      );

      final badCap = _baseConfigJson()..['modelConfidenceCap'] = 1.5;
      expect(
        () => ProofAdmissionConfig.fromJson(badCap),
        throwsFormatException,
      );

      final badVersion = _baseConfigJson()..['version'] = 2;
      expect(
        () => ProofAdmissionConfig.fromJson(badVersion),
        throwsFormatException,
      );
    });
  });

  group('feature vector', () {
    test('rejects out-of-range ratios and negative counts', () {
      expect(() => _features(coverage: 1.4), throwsArgumentError);
      expect(() => _features(citationCount: -1), throwsArgumentError);
      expect(
        () => _features(negativeCorrectionHistory: -2),
        throwsArgumentError,
      );
    });

    test('clamps model confidence and stays free of raw text', () {
      final vector = _features(modelConfidence: 2.5);
      expect(vector.modelConfidence, 1);
      expect(vector.toJson().values.whereType<String>(), isEmpty);
    });
  });

  group('scoring and ranking', () {
    test('hard safety failures are gated out rather than down-weighted', () {
      final ranked = ProofCandidateScorer().rank([
        _candidate('safe'),
        _candidate(
          'unsafe',
          hardSafetyPassed: false,
          features: _features(coverage: 1, specificity: 1, sourceCount: 9),
        ),
      ]);
      expect(ranked.map((item) => item.candidate.stableId), ['safe']);
    });

    test('ranks by weighted score and breaks exact ties canonically', () {
      final scorer = ProofCandidateScorer();
      final ranked = scorer.rank([
        _candidate('b-tie'),
        _candidate('a-tie'),
        _candidate('strong', features: _features(coverage: 1, specificity: 1)),
      ]);
      expect(ranked.map((item) => item.candidate.stableId), [
        'strong',
        'a-tie',
        'b-tie',
      ]);
      expect(ranked[1].weightedScore, ranked[2].weightedScore);
    });

    test('repeated ranking of the same inputs is stable', () {
      final scorer = ProofCandidateScorer();
      List<String> order() => scorer
          .rank([_candidate('one'), _candidate('two'), _candidate('three')])
          .map((item) => item.candidate.stableId)
          .toList();
      expect(order(), order());
    });

    test('duplicate stable IDs are rejected', () {
      expect(
        () =>
            ProofCandidateScorer().rank([_candidate('dup'), _candidate('dup')]),
        throwsArgumentError,
      );
    });

    test(
      'contradiction lowers the score below an otherwise equal candidate',
      () {
        final scorer = ProofCandidateScorer();
        final clean = scorer.score(_candidate('clean'));
        final conflicted = scorer.score(
          _candidate('conflicted', features: _features(contradiction: 1)),
        );
        expect(clean, greaterThan(conflicted));
      },
    );
  });
}
