import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/evidence_receipt_analytics.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

void main() {
  setUp(ProductAnalytics.resetForTest);

  test('receipt funnel analytics contains no journal content', () async {
    await EvidenceReceiptAnalytics.auditableConclusionShown(
      kind: 'observation',
      evidenceCount: 1,
      confidenceBand: 'earlyObservation',
      origin: 'post_save',
    );
    await EvidenceReceiptAnalytics.receiptOpened(
      evidenceCount: 1,
      origin: 'post_save',
    );
    await EvidenceReceiptAnalytics.sourceMomentOpened(
      hasPlayableAudio: true,
      origin: 'post_save',
    );
    await EvidenceReceiptAnalytics.interpretationFeedbackSubmitted(
      kind: 'observation',
      evidenceCount: 1,
      confidenceBand: 'earlyObservation',
      sourceType: 'text',
      feedback: 'wrongAngle',
      entryCount: 1,
      origin: 'post_save',
      corrected: true,
    );

    final encoded = ProductAnalytics.eventsForTest.toString().toLowerCase();
    expect(encoded, contains('auditable_conclusion_shown'));
    expect(encoded, contains('evidence_receipt_opened'));
    expect(encoded, contains('exact_source_opened'));
    expect(encoded, contains('interpretation_corrected'));
    expect(encoded, isNot(contains('graph_opened_from_receipt')));
    for (final privateValue in [
      'transcript',
      'excerpt',
      'entry_id',
      'person_name',
      'audio_path',
    ]) {
      expect(encoded, isNot(contains(privateValue)));
    }
  });
}
