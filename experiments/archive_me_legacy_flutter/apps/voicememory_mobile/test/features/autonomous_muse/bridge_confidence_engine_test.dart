import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/autonomous_muse/bridge_confidence_engine.dart';

void main() {
  const engine = BridgeConfidenceEngine();

  test('routes definitive, actionable, fringe, and discarded scores', () {
    expect(
      engine
          .categorizeScores(cosineSimilarity: .99, rationaleConfidence: .90)
          .band,
      BridgeConfidenceBand.definitive,
    );
    expect(
      engine
          .categorizeScores(cosineSimilarity: .90, rationaleConfidence: .90)
          .band,
      BridgeConfidenceBand.actionable,
    );
    expect(
      engine
          .categorizeScores(cosineSimilarity: .80, rationaleConfidence: .80)
          .band,
      BridgeConfidenceBand.fringe,
    );
    expect(
      engine
          .categorizeScores(cosineSimilarity: .74, rationaleConfidence: .74)
          .band,
      BridgeConfidenceBand.discarded,
    );
  });

  test('rationale confidence can downgrade a high cosine match', () {
    final decision = engine.categorizeScores(
      cosineSimilarity: .96,
      rationaleConfidence: .50,
    );
    expect(decision.band, BridgeConfidenceBand.actionable);
    expect(decision.autoLink, isFalse);
  });
}
