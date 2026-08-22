import 'package:archiveme_mobile/core/json/json_converters.dart';

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

  factory Reflection.fromJson(Map<String, dynamic> json) {
    return Reflection(
      mood: JsonConverters.stringOrEmpty(json['mood']),
      emotionalIntensity: JsonConverters.intOrZero(json['emotionalIntensity']),
      recurringThemes: JsonConverters.stringList(json['recurringThemes']),
      exactLanguagePattern:
          JsonConverters.stringOrEmpty(json['exactLanguagePattern']),
      concreteObservation:
          JsonConverters.stringOrEmpty(json['concreteObservation']),
      repeatedSignal: JsonConverters.stringOrEmpty(json['repeatedSignal']),
      tensionOrContradiction:
          _optionalString(json['tensionOrContradiction']),
      avoidedOrVagueArea: _optionalString(json['avoidedOrVagueArea']),
      nextSmallAction: _optionalString(json['nextSmallAction']),
      patternObservations:
          JsonConverters.stringList(json['patternObservations']),
    );
  }

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

  static String? _optionalString(Object? value) {
    if (value is! String) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  static bool _stringListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reflection &&
          other.mood == mood &&
          other.emotionalIntensity == emotionalIntensity &&
          _stringListsEqual(other.recurringThemes, recurringThemes) &&
          other.exactLanguagePattern == exactLanguagePattern &&
          other.concreteObservation == concreteObservation &&
          other.repeatedSignal == repeatedSignal &&
          other.tensionOrContradiction == tensionOrContradiction &&
          other.avoidedOrVagueArea == avoidedOrVagueArea &&
          other.nextSmallAction == nextSmallAction &&
          _stringListsEqual(other.patternObservations, patternObservations);

  @override
  int get hashCode => Object.hash(
        mood,
        emotionalIntensity,
        Object.hashAll(recurringThemes),
        exactLanguagePattern,
        concreteObservation,
        repeatedSignal,
        tensionOrContradiction,
        avoidedOrVagueArea,
        nextSmallAction,
        Object.hashAll(patternObservations),
      );
}
