import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_store.dart';
import 'package:archiveme_mobile/features/return_day/return_day_flow_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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