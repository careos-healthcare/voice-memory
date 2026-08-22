import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_gates.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Return-day entry for the curiosity loop snapshot screen.
abstract final class YesterdaysSnapshotCoordinator {
  YesterdaysSnapshotCoordinator._();

  static Future<CuriosityHook?> resolveReturnDayHook({
    required List<JournalEntry> entries,
    CuriosityHookRepository? repository,
    DateTime? now,
  }) async {
    await LocalCuriosityHookRepository.ensureLoaded();
    await YesterdaysSnapshotStore.ensureLoaded();

    final repo = repository ?? LocalCuriosityHookRepository.instance();
    final hook = await repo.fetchLatestUnconsumed();
    if (!YesterdaysSnapshotGates.shouldPresentOnReturnDay(
      entries: entries,
      hook: hook,
      now: now,
    )) {
      return null;
    }
    return hook;
  }

  static Future<void> markPresented(CuriosityHook hook) async {
    await YesterdaysSnapshotStore.instance().markPresentedToday(hook.id);
  }

  static Future<void> dismissForDay() async {
    await YesterdaysSnapshotStore.instance().dismissForDay();
  }
}