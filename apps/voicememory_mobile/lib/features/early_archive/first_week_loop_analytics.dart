import 'early_archive_proof_analytics.dart';

/// Safe metadata analytics for the first-week loop — no journal text.
abstract final class FirstWeekLoopAnalytics {
  FirstWeekLoopAnalytics._();

  static void seen({
    required int entryCount,
    required bool hasPhrase,
    required bool hasConfirmedRepeat,
  }) {
    EarlyArchiveProofAnalytics.firstWeekLoopSeen(
      entryCount: entryCount,
      hasPhrase: hasPhrase,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void recordTapped({
    required int entryCount,
    required bool hasPhrase,
    required bool hasConfirmedRepeat,
  }) {
    EarlyArchiveProofAnalytics.firstWeekLoopRecordTapped(
      entryCount: entryCount,
      hasPhrase: hasPhrase,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }
}
