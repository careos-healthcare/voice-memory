import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/memos/life_memo_generator.dart';
import 'package:archiveme_mobile/features/memos/life_memo_schedule.dart';
import 'package:archiveme_mobile/features/memos/life_memo_store.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/background_task_database_session.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

/// Called by the WorkManager entry point on Sunday.
abstract final class LifeMemoBackgroundRunner {
  static Future<bool> run({DatabaseExecutor? db, DateTime? now}) async {
    final clock = now ?? DateTime.now();
    if (db != null) {
      await _write(db, clock);
      return true;
    }
    final session = await BackgroundTaskDatabaseSession.open();
    if (session == null) return true;
    try {
      final database = session.database.sqfliteDatabase;
      if (database == null) return true;
      await _write(database, clock);
      return true;
    } on Object {
      return false;
    } finally {
      await session.close();
    }
  }

  static Future<void> _write(DatabaseExecutor db, DateTime now) async {
    final slot = LifeMemoSchedule.currentSlot(now);
    final start = slot.subtract(
      Duration(days: LifeMemoPeriod.monthly.days),
    );
    final entries = await LifeMemoStore.entriesIn(db, start: start, end: slot);
    final entities = await LifeMemoStore.entitiesIn(
      db,
      start: start,
      end: slot,
    );
    final memos = LifeMemoGenerator.generateDue(
      now: now,
      entries: entries,
      entities: entities,
    );
    for (final memo in memos) {
      await LifeMemoStore.save(db, memo);
    }
  }
}

/// Registers the weekly Sunday 20:00 memo task.
abstract final class LifeMemoWorkScheduler {
  static Future<void> registerSundayTask({
    DateTime? now,
    Future<void> Function({
      required Duration frequency,
      required Duration initialDelay,
    })?
    register,
  }) async {
    final clock = now ?? DateTime.now();
    final delay = LifeMemoSchedule.initialDelay(clock);
    if (register != null) {
      await register(frequency: const Duration(days: 7), initialDelay: delay);
      return;
    }
    if (!V1CapabilityRegistry.backgroundProcessing ||
        kIsWeb ||
        !(Platform.isIOS || Platform.isAndroid)) {
      return;
    }
    await Workmanager().registerPeriodicTask(
      LifeMemoSchedule.taskUniqueName,
      LifeMemoSchedule.taskName,
      frequency: const Duration(days: 7),
      initialDelay: delay,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }
}
