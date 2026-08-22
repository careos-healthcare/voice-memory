import 'dart:convert';

/// Validated, versioned weights for canonical proof-candidate scoring.
final class ProofAdmissionConfig {

  factory ProofAdmissionConfig.fromJsonString(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error, stackTrace) {
      throw FormatException('Invalid proof admission JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Proof admission config must be an object.');
    }
    return ProofAdmissionConfig.fromJson(decoded);
  }

  factory ProofAdmissionConfig.fromJson(Map<String, dynamic> json) {
    const requiredTopLevelKeys = {
      'schema',
      'version',
      'modelConfidenceCap',
      'weights',
    };
    if (json.keys.toSet().difference(requiredTopLevelKeys).isNotEmpty ||
        requiredTopLevelKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Proof admission config has missing or unknown top-level keys.',
      );
    }
    if (json['schema'] != schemaName) {
      throw const FormatException('Unsupported proof admission schema.');
    }
    if (json['version'] != supportedVersion) {
      throw const FormatException('Unsupported proof admission version.');
    }

    final cap = _finiteDouble(json['modelConfidenceCap'], 'modelConfidenceCap');
    if (cap < 0 || cap > 1) {
      throw const FormatException('modelConfidenceCap must be within [0, 1].');
    }

    final rawWeights = json['weights'];
    if (rawWeights is! Map<String, dynamic>) {
      throw const FormatException('weights must be an object.');
    }
    final keys = rawWeights.keys.toSet();
    if (requiredWeightKeys.difference(keys).isNotEmpty ||
        keys.difference(requiredWeightKeys).isNotEmpty) {
      throw const FormatException(
        'weights must contain exactly the required feature keys.',
      );
    }

    final weights = <String, double>{};
    for (final key in requiredWeightKeys) {
      final value = _finiteDouble(rawWeights[key], 'weights.$key');
      if (value < -5 || value > 5) {
        throw FormatException('weights.$key must be within [-5, 5].');
      }
      weights[key] = value;
    }

    return ProofAdmissionConfig._(
      schema: schemaName,
      version: supportedVersion,
      modelConfidenceCap: cap,
      weights: weights,
    );
  }
  ProofAdmissionConfig._({
    required this.schema,
    required this.version,
    required this.modelConfidenceCap,
    required Map<String, double> weights,
  }) : weights = Map.unmodifiable(weights);

  static const schemaName = 'voice_memory.proof_admission_weights';
  static const supportedVersion = 1;
  static const requiredWeightKeys = <String>{
    'coverage',
    'specificity',
    'citationCount',
    'sourceCount',
    'chronology',
    'sourceDiversity',
    'citationSourceRatio',
    'corroborationRatio',
    'contradiction',
    'recency',
    'freshness',
    'transcriptSpecificity',
    'userConfirmed',
    'correctionHistoryCount',
    'acceptedCorrectionRatio',
    'positiveCorrectionHistory',
    'negativeCorrectionHistory',
    'wordingRejectionHistory',
    'evidenceRejectionHistory',
    'oneEntryPenalty',
    'stalePenalty',
    'modelConfidence',
    'deterministicFallback',
  };

  final String schema;
  final int version;
  final double modelConfidenceCap;
  final Map<String, double> weights;

  static double _finiteDouble(Object? value, String path) {
    if (value is! num || !value.isFinite) {
      throw FormatException('$path must be a finite number.');
    }
    return value.toDouble();
  }
}