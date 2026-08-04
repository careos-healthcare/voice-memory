/// Structured telemetry payload from the acoustic and speech processing pipeline.
class CognitiveMetrics {
  final String sessionId;
  final DateTime timestamp;
  final double lexicalDiversity;
  final double emotionalVolatility;
  final double cohesionDrift;
  final Duration pauseDurationTotal;

  const CognitiveMetrics({
    required this.sessionId,
    required this.timestamp,
    required this.lexicalDiversity,
    required this.emotionalVolatility,
    required this.cohesionDrift,
    required this.pauseDurationTotal,
  });

  factory CognitiveMetrics.fromJson(Map<String, dynamic> json) {
    return CognitiveMetrics(
      sessionId: json['session_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      lexicalDiversity: (json['lexical_diversity'] as num).toDouble(),
      emotionalVolatility: (json['emotional_volatility'] as num).toDouble(),
      cohesionDrift: (json['cohesion_drift'] as num).toDouble(),
      pauseDurationTotal: Duration(
        milliseconds: json['pause_duration_ms'] as int,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'lexical_diversity': lexicalDiversity,
    'emotional_volatility': emotionalVolatility,
    'cohesion_drift': cohesionDrift,
    'pause_duration_ms': pauseDurationTotal.inMilliseconds,
  };
}
