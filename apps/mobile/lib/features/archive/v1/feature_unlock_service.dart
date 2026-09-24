import 'dart:async';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

enum FeatureUnlockMilestone { blindSpots, theoryEngines }

/// Entry-count gates for the archive home tools.
class FeatureUnlockState {
  const FeatureUnlockState({
    required this.entryCount,
    required this.loaded,
    this.pendingCelebrations = const [],
  });

  static const initial = FeatureUnlockState(entryCount: 0, loaded: false);

  final int entryCount;
  final bool loaded;
  final List<FeatureUnlockMilestone> pendingCelebrations;

  bool get canSeeBlindSpots =>
      entryCount >= FeatureUnlockService.blindSpotEntries;

  bool get canSeeTheoryEngines =>
      entryCount >= FeatureUnlockService.theoryEngineEntries;

  int remainingFor(FeatureUnlockMilestone milestone) {
    final threshold = switch (milestone) {
      FeatureUnlockMilestone.blindSpots =>
        FeatureUnlockService.blindSpotEntries,
      FeatureUnlockMilestone.theoryEngines =>
        FeatureUnlockService.theoryEngineEntries,
    };
    final left = threshold - entryCount;
    return left < 0 ? 0 : left;
  }
}

/// Counts saved entries in SQLite and remembers which milestones already played.
class FeatureUnlockService {
  FeatureUnlockService(this._db);

  static const blindSpotEntries = 5;
  static const theoryEngineEntries = 10;
  static const stateTable = 'feature_unlock_state';

  final DatabaseExecutor _db;

  Future<FeatureUnlockState> load() async {
    try {
      await _ensureTable();
      final count = await countEntries();
      final celebrated = await _celebrated();
      final pending = <FeatureUnlockMilestone>[];
      if (count >= blindSpotEntries && !celebrated.blindSpots) {
        pending.add(FeatureUnlockMilestone.blindSpots);
      }
      if (count >= theoryEngineEntries && !celebrated.theoryEngines) {
        pending.add(FeatureUnlockMilestone.theoryEngines);
      }
      return FeatureUnlockState(
        entryCount: count,
        loaded: true,
        pendingCelebrations: pending,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'FeatureUnlockService failed to read the entry count',
        error: error,
        stackTrace: stackTrace,
      );
      return const FeatureUnlockState(entryCount: 0, loaded: true);
    }
  }

  Future<FeatureUnlockState> acknowledge(
    FeatureUnlockMilestone milestone,
  ) async {
    await _ensureTable();
    final count = await countEntries();
    final celebrated = await _celebrated();
    await _db.insert(stateTable, {
      'id': 1,
      'last_seen_count': count,
      'celebrated_blind_spots':
          milestone == FeatureUnlockMilestone.blindSpots ||
              celebrated.blindSpots
          ? 1
          : 0,
      'celebrated_theory_engines':
          milestone == FeatureUnlockMilestone.theoryEngines ||
              celebrated.theoryEngines
          ? 1
          : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return load();
  }

  /// Active rows only. A deleted entry does not keep a tool open.
  Future<int> countEntries() async {
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${DatabaseConstants.journalEntriesTable}
      WHERE deleted_at IS NULL
      ''',
    );
    final value = rows.first['count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> _ensureTable() {
    return _db.execute('''
      CREATE TABLE IF NOT EXISTS $stateTable (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        last_seen_count INTEGER NOT NULL DEFAULT 0,
        celebrated_blind_spots INTEGER NOT NULL DEFAULT 0,
        celebrated_theory_engines INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<({bool blindSpots, bool theoryEngines})> _celebrated() async {
    final rows = await _db.query(stateTable, where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return (blindSpots: false, theoryEngines: false);
    final row = rows.first;
    return (
      blindSpots: (row['celebrated_blind_spots'] as int? ?? 0) == 1,
      theoryEngines: (row['celebrated_theory_engines'] as int? ?? 0) == 1,
    );
  }
}

final featureUnlockServiceProvider = Provider<FeatureUnlockService?>((ref) {
  final database = ref.watch(appSqliteDatabaseHolderProvider).value;
  if (database == null) return null;
  return FeatureUnlockService(database.database);
});

class FeatureUnlockNotifier extends Notifier<FeatureUnlockState> {
  @override
  FeatureUnlockState build() {
    final service = ref.watch(featureUnlockServiceProvider);
    if (service == null) return FeatureUnlockState.initial;
    unawaited(refresh());
    return FeatureUnlockState.initial;
  }

  Future<void> refresh() async {
    final service = ref.read(featureUnlockServiceProvider);
    if (service == null) {
      state = FeatureUnlockState.initial;
      return;
    }
    final next = await service.load();
    if (!ref.mounted) return;
    state = next;
  }

  Future<void> acknowledge(FeatureUnlockMilestone milestone) async {
    final service = ref.read(featureUnlockServiceProvider);
    if (service == null) return;
    final next = await service.acknowledge(milestone);
    if (!ref.mounted) return;
    state = next;
  }
}

final featureUnlockProvider =
    NotifierProvider<FeatureUnlockNotifier, FeatureUnlockState>(
      FeatureUnlockNotifier.new,
    );

final canSeeBlindSpotsProvider = Provider<bool>((ref) {
  return ref.watch(featureUnlockProvider).canSeeBlindSpots;
});

final canSeeTheoryEnginesProvider = Provider<bool>((ref) {
  return ref.watch(featureUnlockProvider).canSeeTheoryEngines;
});
