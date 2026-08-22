import 'dart:async';

import 'package:archiveme_mobile/features/beta/beta_activation_loop_tracker.dart';
import 'package:archiveme_mobile/features/early_archive/early_archive_proof_analytics.dart';

/// Safe metadata analytics for the first-week loop — no journal text.
abstract final class FirstWeekLoopAnalytics {
  FirstWeekLoopAnalytics._();

  static void seen({
    required int entryCount,
    required bool hasPhrase,
    required bool hasConfirmedRepeat,
  }) {
    unawaited(BetaActivationLoopTracker.trackReturnedAfterFirstProof());
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