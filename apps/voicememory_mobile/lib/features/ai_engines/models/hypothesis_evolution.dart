import '../../explainable_conclusion/verifiable_citation.dart';

class ConfidenceSnapshot {
  ConfidenceSnapshot({
    required DateTime date,
    required this.confidenceScore,
    required this.triggeringEvidence,
    required this.deltaReasoning,
  }) : date = date.toUtc() {
    if (confidenceScore < 0 || confidenceScore > 100) {
      throw ArgumentError.value(
        confidenceScore,
        'confidenceScore',
        'must be 0–100',
      );
    }
    if (deltaReasoning.trim().isEmpty) {
      throw ArgumentError.value(
        deltaReasoning,
        'deltaReasoning',
        'must not be empty',
      );
    }
  }

  final DateTime date;
  final int confidenceScore;
  final VerifiableCitation triggeringEvidence;
  final String deltaReasoning;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'confidenceScore': confidenceScore,
    'triggeringEvidence': triggeringEvidence.toJson(),
    'deltaReasoning': deltaReasoning,
  };

  static ConfidenceSnapshot? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    final score = json['confidenceScore'];
    final citation = VerifiableCitation.fromJson(json['triggeringEvidence']);
    final reasoning = json['deltaReasoning']?.toString().trim() ?? '';
    if (date == null ||
        score is! int ||
        score < 0 ||
        score > 100 ||
        citation == null ||
        reasoning.isEmpty) {
      return null;
    }
    return ConfidenceSnapshot(
      date: date,
      confidenceScore: score,
      triggeringEvidence: citation,
      deltaReasoning: reasoning,
    );
  }
}

class HypothesisEvolution {
  const HypothesisEvolution({
    required this.theoryId,
    required this.statement,
    required this.evolutionHistory,
  });

  final String theoryId;
  final String statement;
  final List<ConfidenceSnapshot> evolutionHistory;

  int get currentConfidence =>
      evolutionHistory.isEmpty ? 0 : evolutionHistory.last.confidenceScore;
  bool get isActive => currentConfidence < 85;

  Map<String, dynamic> toJson() => {
    'theoryId': theoryId,
    'statement': statement,
    'evolutionHistory': evolutionHistory
        .map((snapshot) => snapshot.toJson())
        .toList(growable: false),
  };

  static HypothesisEvolution? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final theoryId = json['theoryId']?.toString().trim() ?? '';
    final statement = json['statement']?.toString().trim() ?? '';
    final history =
        (json['evolutionHistory'] as List? ?? const [])
            .map(ConfidenceSnapshot.fromJson)
            .whereType<ConfidenceSnapshot>()
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (theoryId.isEmpty || statement.isEmpty || history.isEmpty) return null;
    return HypothesisEvolution(
      theoryId: theoryId,
      statement: statement,
      evolutionHistory: List.unmodifiable(history),
    );
  }
}
