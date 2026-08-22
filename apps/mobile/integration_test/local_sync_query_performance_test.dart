import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/profiling/sqlite_query_profiler.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/storage/sqlite/support/configure_sqlite_test_ffi.dart';
import '../test/sync/integration/sync_integration_test_harness.dart';
import 'support/timeline_performance_metrics.dart';

/// Integration performance test for encrypted local sync + SQLite query paths.
///
/// Requires a connected iOS/Android device or simulator (`integration_test`
/// cannot run headless on the Dart VM alone). Example:
///
/// ```sh
/// flutter test integration_test/local_sync_query_performance_test.dart -d <device-id>
/// # or
/// tool/run_local_sync_query_performance_test.sh drive
/// ```

/// Number of remote journal rows pulled during the heavy sync phase.
const _remoteEntryCount = 800;

/// Pending local edits pushed during the heavy sync phase.
const _localEditCount = 75;

/// Paginated read batches executed during the encrypted read phase.
const _readPageCount = 12;

/// FTS queries executed during the search phase.
const _ftsQueryCount = 24;

const _performanceBudgetsPath =
    'test/fixtures/performance/local_sync_query_performance_budgets.json';

Reflection _reflection() => const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: ['focus'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    );

JournalEntry _remoteEntry(int index) {
  return JournalEntry(
    id: 'entry-$index',
    createdAt: DateTime.utc(2026, 8, 19).add(Duration(minutes: index)),
    transcript: index == _remoteEntryCount - 1
        ? 'target capture context transcript searchable'
        : 'filler transcript $index with searchable terms',
    durationSeconds: 30,
    reflection: _reflection(),
    revision: 1,
    changeId: 'remote-change-$index',
    syncStatus: SyncStatus.synced,
  );
}

List<JournalEntry> _remoteSnapshot() {
  return List.generate(_remoteEntryCount, _remoteEntry);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      configureSqliteTestFfi();
    }
    SqliteQueryProfiler.enabledOverride = true;
  });

  tearDownAll(() {
    SqliteQueryProfiler.enabledOverride = null;
  });

  testWidgets(
    'heavy local sync + encrypted query workflow reports timelines',
    (tester) async {
    final harness = await SyncIntegrationTestHarness.create();
    addTearDown(harness.dispose);

    final remoteEntries = _remoteSnapshot();
    final budgets = TimelinePerformanceBudgets.load(
      assetPath: _performanceBudgetsPath,
    );
    final observedMetrics = <String, TimelinePerformanceMetrics>{};

    Future<void> recordPhase({
      required String phase,
      required Future<void> Function() action,
    }) async {
      await binding.traceAction(
        action,
        reportKey: '${phase}_timeline',
      );

      final timelineJson = binding.reportData?['${phase}_timeline'];
      expect(
        timelineJson,
        isA<Map<String, dynamic>>(),
        reason: 'Missing timeline for $phase',
      );

      final metrics = TimelinePerformanceMetrics.fromTimelineJson(
        Map<String, dynamic>.from(timelineJson! as Map),
      );
      observedMetrics[phase] = metrics;

      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['${phase}_metrics'] = metrics.toJson();

      debugPrint(
        'PERF $phase: '
        '${metrics.wallClockMs.toStringAsFixed(1)}ms wall, '
        '${metrics.sqliteOperationMs.toStringAsFixed(1)}ms sqlite '
        '(${metrics.sqliteOperationCount} ops)',
      );

      final budget = budgets[phase];
      expect(budget, isNotNull, reason: 'Missing budget for $phase');
      TimelinePerformanceBudgets.assertWithinBudget(
        phase: phase,
        metrics: metrics,
        budget: budget!,
      );
    }

    await recordPhase(
      phase: 'heavy_local_sync',
      action: () async {
        harness.setRemoteSnapshot(remoteEntries);
        final pull = await harness.syncNow();
        expect(pull.cloudSyncSucceeded, isTrue);

        await harness.mirrorJournalToSqlite();
        expect(await harness.journalSqlite.countActive(), _remoteEntryCount);

        for (var index = 0; index < _localEditCount; index++) {
          final existing = await harness.journal.getById('entry-$index');
          expect(existing, isNotNull);
          await harness.savePendingEdit(
            existing!.copyWith(
              transcript: 'local edit $index after pull',
              revision: existing.revision + 1,
              changeId: 'local-change-$index',
            ),
          );
        }

        final push = await harness.syncNow();
        expect(push.cloudSyncSucceeded, isTrue);
        await harness.mirrorJournalToSqlite();
      },
    );

    await recordPhase(
      phase: 'encrypted_read_queries',
      action: () async {
        for (var page = 0; page < _readPageCount; page++) {
          final rows = await harness.journalSqlite.fetchPage(
            offset: page * JournalSqliteRepository.defaultPageSize,
          );
          expect(rows, isNotEmpty);
        }

        for (var index = 0; index < 50; index++) {
          final rows = await harness.sqlite.database.query(
            'journal_entries',
            columns: const [
              'id',
              'created_at',
              'updated_at',
              'deleted_at',
              'is_archived',
              'transcript',
              'has_verified_proof',
              'payload_json',
            ],
            where: 'id = ?',
            whereArgs: ['entry-${index * 10}'],
            limit: 1,
          );
          expect(rows, hasLength(1));
        }
      },
    );

    await recordPhase(
      phase: 'fts5_full_text_search',
      action: () async {
        const queries = [
          'filler transcript',
          'searchable terms',
          'target capture context',
          'local edit',
        ];

        for (var round = 0; round < _ftsQueryCount ~/ queries.length; round++) {
          for (final query in queries) {
            final hits = await harness.journalSqlite.fetchPage(
              offset: 0,
              searchQuery: query,
            );
            expect(hits, isNotEmpty);
          }
        }
      },
    );

    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['local_sync_query_performance_summary'] =
        observedMetrics.map(
      (phase, metrics) => MapEntry(phase, metrics.toJson()),
    );

    if (Platform.environment['UPDATE_PERF_BUDGETS'] == '1') {
      writePerformanceBudgetsFromMetrics(
        observedMetrics,
        outputPath: _performanceBudgetsPath,
      );
    }
  },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
