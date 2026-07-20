import '../../models/journal_entry.dart';
import '../return_day/return_day_flow_engine.dart';
import 'models/curiosity_hook.dart';
import 'yesterdays_snapshot_store.dart';

/// Visibility gates for return-day Yesterday's Snapshot presentation.
abstract final class YesterdaysSnapshotGates {
  YesterdaysSnapshotGates._();

  static bool shouldPresentOnReturnDay({
    required List<JournalEntry> entries,
    required CuriosityHook? hook,
    DateTime? now,
  }) {
    if (hook == null || hook.isConsumed) return false;
    if (YesterdaysSnapshotStore.isDismissedToday) return false;
    if (YesterdaysSnapshotStore.presentedTodayForHook(hook.id)) return false;
    if (!ReturnDayFlowGates.archiveAllowsFlow(entries)) return false;
    if (!ReturnDayFlowGates.returnedOnLaterDay(entries: entries, now: now)) {
      return false;
    }
    return true;
  }
}
