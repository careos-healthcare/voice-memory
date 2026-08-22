import 'dart:io';

import 'package:archiveme_mobile/features/weekly_synthesis/data/recurrent_topic_node_query.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/data/weekly_synthesis_repository.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/domain/weekly_topic_synthesis.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('RecurrentTopicNodeQuery', () {
    test('returns theme clusters indexed in FTS5 with min mention count', () async {
      final dir = await Directory.systemTemp.createTemp('weekly_topics_');
      final dbPath = '${dir.path}/graph.db';
      final db = await databaseFactory.openDatabase(dbPath);
      await SqliteMigrationManager().runToVersion(db, 11);

      final now = DateTime.utc(2026, 8, 20, 12);
      final weekAgo = now.subtract(const Duration(days: 3));

      await _insertThemeNode(
        db,
        id: 'theme:work:1',
        entryId: 'entry-1',
        label: 'Work pressure',
        updatedAt: weekAgo,
      );
      await _insertThemeNode(
        db,
        id: 'theme:work:2',
        entryId: 'entry-2',
        label: 'work pressure',
        updatedAt: weekAgo,
      );
      await _insertThemeNode(
        db,
        id: 'theme:sleep:1',
        entryId: 'entry-3',
        label: 'Sleep',
        updatedAt: weekAgo,
      );

      final query = RecurrentTopicNodeQuery(db);
      final clusters = await query.fetchRecurrentTopics(
        since: now.subtract(const Duration(days: 7)),
        minMentions: 2,
      );

      expect(clusters, hasLength(1));
      expect(clusters.single.displayLabel, 'Work pressure');
      expect(clusters.single.mentionCount, 2);

      await db.close();
      await dir.delete(recursive: true);
    });
  });

  group('WeeklySynthesisRepository', () {
    test('persists synthesis node into graph + FTS tables', () async {
      final dir = await Directory.systemTemp.createTemp('weekly_synth_repo_');
      final dbPath = '${dir.path}/graph.db';
      final db = await databaseFactory.openDatabase(dbPath);
      await SqliteMigrationManager().runToVersion(db, 11);

      final repository = WeeklySynthesisRepository(db);
      const weekKey = '2026-W34';
      expect(await repository.hasSynthesisForWeek(weekKey), isFalse);

      final synthesis = WeeklyTopicSynthesis(
        weekStart: DateTime.utc(2026, 8, 18),
        weekKey: weekKey,
        headline: 'Work and rest',
        summary: 'You kept returning to work pressure and sleep balance.',
        sourceNodeIds: const ['theme:work:1', 'theme:sleep:1'],
        recurringThemeLabels: const ['Work pressure', 'Sleep'],
        generatedAt: DateTime.utc(2026, 8, 20),
      );

      await repository.saveSynthesis(synthesis);
      expect(await repository.hasSynthesisForWeek(weekKey), isTrue);

      final rows = await db.query(
        Migration011ReflectionGraphFts.nodesTable,
        where: 'id = ?',
        whereArgs: [synthesis.nodeId],
      );
      expect(rows, hasLength(1));
      expect(rows.single['kind'], 'weekly_synthesis');

      await db.close();
      await dir.delete(recursive: true);
    });
  });
}

Future<void> _insertThemeNode(
  Database db, {
  required String id,
  required String entryId,
  required String label,
  required DateTime updatedAt,
}) async {
  await db.insert(Migration011ReflectionGraphFts.nodesTable, {
    'id': id,
    'entry_id': entryId,
    'kind': 'theme',
    'label': label,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  });
  await db.insert(Migration011ReflectionGraphFts.ftsTable, {
    'node_id': id,
    'entry_id': entryId,
    'kind': 'theme',
    'label': label,
  });
}
