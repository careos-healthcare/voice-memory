import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_020_entity_graph.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_026_habits.dart';
import 'package:sqflite/sqflite.dart';

/// How often a habit is expected.
abstract final class HabitFrequency {
  static const daily = 'daily';
  static const weekly = 'weekly';
}

/// One tracked habit, optionally tied to a graph entity.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.frequency,
    required this.targetCount,
    required this.createdAt,
    this.entityId,
  });

  factory Habit.fromRow(Map<String, Object?> row) {
    return Habit(
      id: '${row['id']}',
      entityId: row['entity_id'] as String?,
      title: '${row['title'] ?? ''}',
      frequency: '${row['frequency'] ?? HabitFrequency.daily}',
      targetCount: (row['target_count'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final String id;
  final String? entityId;
  final String title;
  final String frequency;
  final int targetCount;
  final DateTime createdAt;
}

/// A completion, either from a moment or a manual log.
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.loggedAt,
    this.entryId,
  });

  factory HabitLog.fromRow(Map<String, Object?> row) {
    final entry = row['entry_id'] as String?;
    return HabitLog(
      id: '${row['id']}',
      habitId: '${row['habit_id']}',
      entryId: entry == null || entry.isEmpty ? null : entry,
      loggedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['logged_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final String id;
  final String habitId;
  final String? entryId;
  final DateTime loggedAt;
}

/// Creates habits and links spoken completions to moments.
class HabitTrackerService {
  HabitTrackerService({required this.database, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DatabaseExecutor database;
  final DateTime Function() _clock;
  var _sequence = 0;

  Future<Habit> create({
    required String title,
    String frequency = HabitFrequency.daily,
    int targetCount = 1,
    String? entityId,
  }) async {
    final created = _clock();
    final habit = Habit(
      id: _nextId('habit'),
      entityId: entityId,
      title: title.trim(),
      frequency: frequency,
      targetCount: targetCount < 1 ? 1 : targetCount,
      createdAt: created,
    );
    await database.insert(Migration026Habits.habitsTable, {
      'id': habit.id,
      'entity_id': habit.entityId,
      'title': habit.title,
      'frequency': habit.frequency,
      'target_count': habit.targetCount,
      'created_at': created.millisecondsSinceEpoch,
    });
    return habit;
  }

  Future<List<Habit>> listHabits() async {
    final rows = await database.query(
      Migration026Habits.habitsTable,
      orderBy: 'created_at ASC',
    );
    return [for (final row in rows) Habit.fromRow(row)];
  }

  Future<List<HabitLog>> logsFor(String habitId) async {
    final rows = await database.query(
      Migration026Habits.logsTable,
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'logged_at ASC',
    );
    return [for (final row in rows) HabitLog.fromRow(row)];
  }

  /// Writes a log that is not tied to a recording.
  Future<HabitLog> logManual(String habitId, {DateTime? at}) async {
    final loggedAt = at ?? _clock();
    final log = HabitLog(
      id: _nextId('log'),
      habitId: habitId,
      loggedAt: loggedAt,
    );
    await database.insert(Migration026Habits.logsTable, {
      'id': log.id,
      'habit_id': habitId,
      'entry_id': null,
      'logged_at': loggedAt.millisecondsSinceEpoch,
    });
    return log;
  }

  /// Links a moment when its words complete an active habit.
  Future<List<HabitLog>> detectFromMoment({
    required String entryId,
    required String transcript,
    DateTime? loggedAt,
  }) async {
    final when = loggedAt ?? _clock();
    final habits = await listHabits();
    final names = await _entityNames();
    final created = <HabitLog>[];
    for (final habit in habits) {
      final labels = [
        habit.title,
        if (habit.entityId != null) names[habit.entityId!] ?? '',
      ];
      if (!mentionsHabitCompletion(transcript, labels)) continue;
      if (await _alreadyLogged(habit.id, entryId)) continue;
      final log = HabitLog(
        id: _nextId('log'),
        habitId: habit.id,
        entryId: entryId,
        loggedAt: when,
      );
      await database.insert(Migration026Habits.logsTable, {
        'id': log.id,
        'habit_id': habit.id,
        'entry_id': entryId,
        'logged_at': when.millisecondsSinceEpoch,
      });
      created.add(log);
    }
    return created;
  }

  Future<Map<String, String>> _entityNames() async {
    final rows = await database.query(
      Migration020EntityGraph.entitiesTable,
      columns: ['id', 'name'],
    );
    return {for (final row in rows) '${row['id']}': '${row['name'] ?? ''}'};
  }

  Future<bool> _alreadyLogged(String habitId, String entryId) async {
    final rows = await database.query(
      Migration026Habits.logsTable,
      columns: ['id'],
      where: 'habit_id = ? AND entry_id = ?',
      whereArgs: [habitId, entryId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  String _nextId(String prefix) {
    _sequence += 1;
    return '$prefix-${_clock().microsecondsSinceEpoch}-$_sequence';
  }
}

/// True when [transcript] describes finishing one of [labels].
bool mentionsHabitCompletion(String transcript, List<String> labels) {
  final text = transcript.toLowerCase();
  if (text.trim().isEmpty) return false;
  final completed = RegExp(
    r'\b(went|finished|did|completed|ran|practiced|logged)\b',
  ).hasMatch(text);
  for (final raw in labels) {
    final name = raw.toLowerCase().trim();
    if (name.length < 3 || !text.contains(name)) continue;
    final words = name.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    if (words.length >= 2 || completed) return true;
  }
  return false;
}

/// Stable entity id for a habit name in the goals category.
String habitEntityId(String name) =>
    entityStorageId(EntityCategories.goals, name);
