import 'package:crypto/crypto.dart';

import '../../services/ai/local_semantic_store.dart';
import '../ai_engines/models/ai_explainability.dart';
import '../ai_engines/models/hypothesis_evolution.dart';

class HypothesisTrackingEngine {
  const HypothesisTrackingEngine(this.store);

  final LocalSemanticStore store;

  static String stableTheoryId(String statement) {
    final normalized = statement.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final digest = sha256.convert(normalized.codeUnits).toString();
    return 'theory-${digest.substring(0, 24)}';
  }

  Future<HypothesisEvolution> track({
    String? theoryId,
    required String statement,
    required int confidenceScore,
    required VerifiableCitation triggeringEvidence,
    required String deltaReasoning,
    DateTime? date,
  }) async {
    final id = theoryId?.trim().isNotEmpty == true
        ? theoryId!.trim()
        : stableTheoryId(statement);
    final current = await store.hypothesisById(id);
    final snapshot = ConfidenceSnapshot(
      date: date ?? DateTime.now().toUtc(),
      confidenceScore: confidenceScore,
      triggeringEvidence: triggeringEvidence,
      deltaReasoning: deltaReasoning,
    );
    final history = [...?current?.evolutionHistory];
    final duplicate = history.any(
      (item) =>
          item.date == snapshot.date &&
          item.confidenceScore == snapshot.confidenceScore &&
          item.triggeringEvidence.sourceEntryId ==
              snapshot.triggeringEvidence.sourceEntryId &&
          item.triggeringEvidence.exactQuote ==
              snapshot.triggeringEvidence.exactQuote,
    );
    if (!duplicate) history.add(snapshot);
    history.sort((a, b) => a.date.compareTo(b.date));
    final evolution = HypothesisEvolution(
      theoryId: id,
      statement: statement,
      evolutionHistory: List.unmodifiable(history),
    );
    await store.upsertHypothesis(evolution);
    return evolution;
  }

  Future<HypothesisEvolution> trackExplainability({
    required String statement,
    required AiExplainability explainability,
    required String deltaReasoning,
    DateTime? date,
  }) {
    if (explainability.evidence.isEmpty) {
      throw ArgumentError('A confidence shift requires triggering evidence.');
    }
    return track(
      theoryId: explainability.theoryId,
      statement: statement,
      confidenceScore: explainability.confidencePercentage,
      triggeringEvidence: explainability.evidence.first,
      deltaReasoning: deltaReasoning,
      date: date,
    );
  }

  Future<List<HypothesisEvolution>> activeHypotheses() =>
      store.activeHypotheses();
}
