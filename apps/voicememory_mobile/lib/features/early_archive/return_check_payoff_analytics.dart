import 'early_archive_proof_analytics.dart';
import 'return_check_payoff_model.dart';

/// Safe metadata analytics for the return-check payoff — no journal text.
abstract final class ReturnCheckPayoffAnalytics {
  ReturnCheckPayoffAnalytics._();

  static void seen({
    required int entryCount,
    required ReturnCheckPayoffComparisonState comparisonState,
    required bool hasPhrase,
    required bool hasConfirmedRepeat,
  }) {
    EarlyArchiveProofAnalytics.returnCheckPayoffSeen(
      entryCount: entryCount,
      comparisonState: comparisonState.analyticsValue,
      hasPhrase: hasPhrase,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }
}
