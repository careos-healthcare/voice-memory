// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: config/proof_admission_weights.v1.json

import '../proof_admission_config.dart';

const generatedProofAdmissionConfigJson = r'''
{
  "schema": "voice_memory.proof_admission_weights",
  "version": 1,
  "modelConfidenceCap": 0.85,
  "weights": {
    "coverage": 2.0,
    "specificity": 2.5,
    "citationCount": 0.35,
    "sourceCount": 0.75,
    "chronology": 1.25,
    "sourceDiversity": 1.5,
    "citationSourceRatio": 1.0,
    "corroborationRatio": 1.5,
    "contradiction": -3.5,
    "recency": 0.75,
    "freshness": 0.75,
    "transcriptSpecificity": 1.5,
    "userConfirmed": 2.0,
    "correctionHistoryCount": 0.2,
    "acceptedCorrectionRatio": 0.75,
    "positiveCorrectionHistory": 0.35,
    "negativeCorrectionHistory": -0.75,
    "wordingRejectionHistory": -0.45,
    "evidenceRejectionHistory": -1.0,
    "oneEntryPenalty": -2.0,
    "stalePenalty": -1.5,
    "modelConfidence": 0.5,
    "deterministicFallback": -0.5
  }
}
''';

final generatedProofAdmissionConfig = ProofAdmissionConfig.fromJsonString(
  generatedProofAdmissionConfigJson,
);