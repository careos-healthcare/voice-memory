import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for first proof truth follow-up — metadata only.
abstract final class FirstProofTruthAnalytics {
  FirstProofTruthAnalytics._();

  static const answeredEvent = 'first_proof_truth_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void answered({
    required String source,
    required int entryCount,
    required String answer,
    required bool hasSnippets,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'answer': answer,
      'has_snippets': hasSnippets ? 1 : 0,
    };

    captureForTest?.call(answeredEvent, props);
    ActivationFunnelAnalytics.track(
      answeredEvent,
      source: source,
      entryCount: entryCount,
      answer: answer,
      hasSnippets: hasSnippets,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_FIRST_PROOF_TRUTH event=$answeredEvent source=$source '
        'entry_count=$entryCount answer=$answer has_snippets=$hasSnippets',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
