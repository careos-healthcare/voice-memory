import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import 'beta_activation_loop_counts.dart';
import 'beta_activation_loop_store.dart';

/// Local beta counters for the first-three-entry loop — debug summary only.
abstract class BetaActivationLoopTracker {
  BetaActivationLoopTracker._();

  static const _sessionDedupeKeys = <String>{
    'appOpened',
    'recordScreenSeen',
    'oneEntryReturnScreenSeen',
    'twoEntryRelatedSeen',
    'twoEntryUnrelatedSeen',
    'confirmedRepeatSeen',
    'paywallSeen',
  };

  static final Set<String> _sessionSeen = <String>{};

  @visibleForTesting
  static void resetSessionForTest() {
    _sessionSeen.clear();
  }

  static Future<void> trackAppOpened() =>
      _increment('appOpened', sessionDedupe: true);

  static Future<void> trackRecordScreenSeen() =>
      _increment('recordScreenSeen', sessionDedupe: true);

  static Future<void> trackFirstMomentSaved() =>
      _increment('firstMomentSaved');

  static Future<void> trackOneEntryReturnScreenSeen() =>
      _increment('oneEntryReturnScreenSeen', sessionDedupe: true);

  static Future<void> trackSecondMomentSaved() =>
      _increment('secondMomentSaved');

  static Future<void> trackTwoEntryRelatedSeen() =>
      _increment('twoEntryRelatedSeen', sessionDedupe: true);

  static Future<void> trackTwoEntryUnrelatedSeen() =>
      _increment('twoEntryUnrelatedSeen', sessionDedupe: true);

  static Future<void> trackThirdMomentSaved() =>
      _increment('thirdMomentSaved');

  static Future<void> trackConfirmedRepeatSeen() =>
      _increment('confirmedRepeatSeen', sessionDedupe: true);

  static Future<void> trackPaywallSeen() =>
      _increment('paywallSeen', sessionDedupe: true);

  static Future<void> trackRestoreTapped() => _increment('restoreTapped');

  static Future<void> trackPurchaseTapped() => _increment('purchaseTapped');

  static Future<BetaActivationLoopCounts> readCounts() async {
    if (!AppServices.isInitialized) return const BetaActivationLoopCounts();
    return BetaActivationLoopStore.fromAppServices().read();
  }

  static Future<void> clearCounts() async {
    if (!AppServices.isInitialized) return;
    await BetaActivationLoopStore.fromAppServices().clear();
  }

  static Future<void> _increment(
    String field, {
    bool sessionDedupe = false,
  }) async {
    if (!AppServices.isInitialized) return;
    if (sessionDedupe && _sessionDedupeKeys.contains(field)) {
      if (!_sessionSeen.add(field)) return;
    }
    final counts = await BetaActivationLoopStore.fromAppServices().increment(field);
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_ACTIVATION_LOOP event=$field '
        'count=${counts.valueForField(field)}',
      );
    }
  }
}
