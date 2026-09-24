import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/features/security/private_vault_gate.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/painting.dart';
import 'package:sqflite/sqflite.dart';

/// Shade for a day, darker as more moments were saved. Tone is ignored.
Color captureVolumeColor(int count) {
  if (count <= 0) return AppTokens.neutral200;
  final level = switch (count) {
    1 => 0,
    2 => 1,
    <= 4 => 2,
    _ => 3,
  };
  return const [
    AppTokens.primary200,
    AppTokens.primary400,
    AppTokens.primary600,
    AppTokens.primary800,
  ][level];
}

/// Consecutive days with at least one capture, ending today or yesterday.
int captureStreak(Map<String, int> counts, DateTime today) {
  var cursor = dateOnly(today);
  if ((counts[dayKey(cursor)] ?? 0) <= 0) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while ((counts[dayKey(cursor)] ?? 0) > 0) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Local-day capture totals from `journal_entries`.
abstract final class CaptureConsistencyStore {
  static Future<Map<String, int>> dailyCounts(DatabaseExecutor db) async {
    final hidden = await PrivateVaultGate.andSql(db, '');
    final rows = await db.rawQuery('''
      SELECT created_at
      FROM journal_entries
      WHERE deleted_at IS NULL$hidden
    ''');
    final counts = <String, int>{};
    for (final row in rows) {
      final created = row['created_at'];
      if (created is! int) continue;
      final key = dayKey(DateTime.fromMillisecondsSinceEpoch(created));
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }
}
