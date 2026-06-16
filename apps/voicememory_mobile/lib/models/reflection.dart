class Reflection {
  const Reflection({
    required this.mood,
    required this.emotionalIntensity,
    required this.recurringThemes,
    required this.exactLanguagePattern,
    required this.concreteObservation,
    required this.repeatedSignal,
    this.tensionOrContradiction,
    this.avoidedOrVagueArea,
    this.nextSmallAction,
    this.patternObservations = const [],
  });

  final String mood;
  final int emotionalIntensity;
  final List<String> recurringThemes;
  final String exactLanguagePattern;
  final String concreteObservation;
  final String repeatedSignal;
  final String? tensionOrContradiction;
  final String? avoidedOrVagueArea;
  final String? nextSmallAction;
  final List<String> patternObservations;

  factory Reflection.fromJson(Map<String, dynamic> json) {
    final themes = (json['recurringThemes'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final patterns = (json['patternObservations'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    return Reflection(
      mood: json['mood'] as String? ?? '',
      emotionalIntensity: (json['emotionalIntensity'] as num?)?.toInt() ?? 0,
      recurringThemes: themes,
      exactLanguagePattern: json['exactLanguagePattern'] as String? ?? '',
      concreteObservation: json['concreteObservation'] as String? ?? '',
      repeatedSignal: json['repeatedSignal'] as String? ?? '',
      tensionOrContradiction: _optionalString(json['tensionOrContradiction']),
      avoidedOrVagueArea: _optionalString(json['avoidedOrVagueArea']),
      nextSmallAction: _optionalString(json['nextSmallAction']),
      patternObservations: patterns,
    );
  }

  Map<String, dynamic> toJson() => {
    'mood': mood,
    'emotionalIntensity': emotionalIntensity,
    'recurringThemes': recurringThemes,
    'hiddenConcern': '',
    'positiveSignal': '',
    'recommendation': '',
    'exactLanguagePattern': exactLanguagePattern,
    'concreteObservation': concreteObservation,
    'repeatedSignal': repeatedSignal,
    if (tensionOrContradiction != null)
      'tensionOrContradiction': tensionOrContradiction,
    if (avoidedOrVagueArea != null) 'avoidedOrVagueArea': avoidedOrVagueArea,
    if (nextSmallAction != null) 'nextSmallAction': nextSmallAction,
    if (patternObservations.isNotEmpty)
      'patternObservations': patternObservations,
  };

  static String? _optionalString(dynamic value) {
    if (value is! String) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
