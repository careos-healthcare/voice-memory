/// Clinical cognitive care signals derived from voice journal analysis.
class CognitiveBiomarkers {
  const CognitiveBiomarkers({
    required this.lexicalDiversity,
    required this.cohesionDrift,
    required this.emotionalVolatility,
  });

  final double lexicalDiversity;
  final double cohesionDrift;
  final double emotionalVolatility;

  CognitiveBiomarkers copyWith({
    double? lexicalDiversity,
    double? cohesionDrift,
    double? emotionalVolatility,
  }) {
    return CognitiveBiomarkers(
      lexicalDiversity: lexicalDiversity ?? this.lexicalDiversity,
      cohesionDrift: cohesionDrift ?? this.cohesionDrift,
      emotionalVolatility: emotionalVolatility ?? this.emotionalVolatility,
    );
  }

  Map<String, dynamic> toJson() => {
        'lexicalDiversity': lexicalDiversity,
        'cohesionDrift': cohesionDrift,
        'emotionalVolatility': emotionalVolatility,
      };

  static CognitiveBiomarkers? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final lexicalDiversity = _parseScore(map['lexicalDiversity']);
    final cohesionDrift = _parseScore(map['cohesionDrift']);
    final emotionalVolatility = _parseScore(map['emotionalVolatility']);
    if (lexicalDiversity == null ||
        cohesionDrift == null ||
        emotionalVolatility == null) {
      return null;
    }
    return CognitiveBiomarkers(
      lexicalDiversity: lexicalDiversity,
      cohesionDrift: cohesionDrift,
      emotionalVolatility: emotionalVolatility,
    );
  }

  static double? _parseScore(dynamic raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CognitiveBiomarkers &&
            other.lexicalDiversity == lexicalDiversity &&
            other.cohesionDrift == cohesionDrift &&
            other.emotionalVolatility == emotionalVolatility;
  }

  @override
  int get hashCode => Object.hash(
        lexicalDiversity,
        cohesionDrift,
        emotionalVolatility,
      );
}
