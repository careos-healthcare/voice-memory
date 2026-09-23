import 'package:archiveme_mobile/features/monetization/paywall_milestone.dart';
import 'package:flutter/foundation.dart';

/// Remembers archive wins and asks a mounted host to open the paywall once.
class PaywallMilestoneCoordinator extends ChangeNotifier {
  PaywallMilestoneCoordinator();

  static final PaywallMilestoneCoordinator instance =
      PaywallMilestoneCoordinator();

  PaywallMilestoneSnapshot _snapshot = PaywallMilestoneSnapshot.initial;

  PaywallMilestoneSnapshot get snapshot => _snapshot;

  PaywallMicroWin? get pending => _snapshot.pending;

  static Future<void> onDurableSave({
    required int activeCountAfter,
    required DateTime savedAt,
    required Set<String> activeDayKeys,
    required bool isFirstEntryOnSavedDay,
  }) async {
    instance.recordNewArchive(
      activeCountAfter: activeCountAfter,
      savedAt: savedAt,
      activeDayKeys: activeDayKeys,
      isFirstEntryOnSavedDay: isFirstEntryOnSavedDay,
    );
  }

  void recordNewArchive({
    required int activeCountAfter,
    required DateTime savedAt,
    required Set<String> activeDayKeys,
    required bool isFirstEntryOnSavedDay,
  }) {
    final next = PaywallMilestoneEngine.record(
      current: _snapshot,
      activeCountAfter: activeCountAfter,
      activeDayKeys: activeDayKeys,
      savedAt: savedAt,
      isFirstEntryOnSavedDay: isFirstEntryOnSavedDay,
    );
    final becamePending = _snapshot.pending == null && next.pending != null;
    _snapshot = next;
    if (becamePending) notifyListeners();
  }

  /// Returns the win that should open the sheet, and marks met wins as shown.
  PaywallMicroWin? claimPending() {
    final win = _snapshot.pending;
    if (win == null) return null;
    final celebrated = Set<PaywallMicroWin>.from(_snapshot.celebrated)
      ..add(win);
    if (_snapshot.completedArchives >= PaywallMilestoneEngine.archiveTarget) {
      celebrated.add(PaywallMicroWin.fiveCompletedArchives);
    }
    if (PaywallMilestoneEngine.consecutiveStreak(
          _snapshot.activeDayKeys,
          _snapshot.asOf,
        ) >=
        PaywallMilestoneEngine.streakTarget) {
      celebrated.add(PaywallMicroWin.threeDayStreak);
    }
    _snapshot = _snapshot.copyWith(
      celebrated: celebrated,
      clearPending: true,
    );
    return win;
  }

  @visibleForTesting
  void resetForTest() {
    _snapshot = PaywallMilestoneSnapshot.initial;
  }
}
