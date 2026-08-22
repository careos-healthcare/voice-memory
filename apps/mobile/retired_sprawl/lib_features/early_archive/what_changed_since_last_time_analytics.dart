import 'package:archiveme_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:archiveme_mobile/features/early_archive/return_check_payoff_model.dart';

/// Safe metadata analytics for Patterns longitudinal change — no journal text.
abstract final class WhatChangedSinceLastTimeAnalytics {
  WhatChangedSinceLastTimeAnalytics._();

  static void seen({
    required int entryCount,
    required ReturnCheckPayoffComparisonState comparisonState,
    required bool hasPhrase,
    required bool hasConfirmedRepeat,
  }) {
    EarlyArchiveProofAnalytics.whatChangedSinceLastTimeSeen(
      entryCount: entryCount,
      comparisonState: comparisonState.analyticsValue,
      hasPhrase: hasPhrase,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }
}