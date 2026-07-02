import 'package:flutter/foundation.dart' show visibleForTesting;

import 'early_archive_proof_analytics.dart';

/// Safe metadata analytics for helpful-action appeared — no journal text.
abstract final class HelpfulActionAppearedAnalytics {
  HelpfulActionAppearedAnalytics._();

  @visibleForTesting
  static void Function(String event, Map<String, Object> props)? captureForTest;

  static void seen({
    required int entryCount,
    required String source,
    required bool hasActionPhrase,
    required bool hasConfirmedRepeat,
  }) {
    final props = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'has_action_phrase': hasActionPhrase ? 1 : 0,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
    };
    if (captureForTest != null) {
      captureForTest!(
        EarlyArchiveProofAnalytics.helpfulActionAppearedSeenEvent,
        props,
      );
      return;
    }
    EarlyArchiveProofAnalytics.helpfulActionAppearedSeen(
      entryCount: entryCount,
      source: source,
      hasActionPhrase: hasActionPhrase,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
