import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/features/actionable_memory/actionable_memory_models.dart';
import 'package:archiveme_mobile/storage/sqlite/time_capsule_visibility.dart';
import 'package:sqflite/sqflite.dart';

/// Reads older journal rows that share words, a place, or a calendar title
/// with the current context. Locked time capsules stay out.
class ActionableMemoryQuery {
  const ActionableMemoryQuery({
    this.minimumAge = const Duration(days: 1),
    this.scanLimit = 200,
    this.resultLimit = 5,
  });

  final Duration minimumAge;
  final int scanLimit;
  final int resultLimit;

  Future<List<ActionableMemoryHit>> find(
    DatabaseExecutor db,
    ActionableMemoryContext context,
  ) async {
    final terms = context.focusTerms;
    final place = context.locality?.trim().toLowerCase();
    final calendarTerms = context.calendarTerms;
    final hasSignal =
        terms.isNotEmpty ||
        (place != null && place.isNotEmpty) ||
        calendarTerms.isNotEmpty;
    if (!hasSignal) return const [];

    final cutoff = context.now
        .toUtc()
        .subtract(minimumAge)
        .millisecondsSinceEpoch;
    final locked = await TimeCapsuleVisibility.lockedEntryIds(
      db,
      now: context.now,
    );
    final rows = await db.rawQuery(
      '''
      SELECT id, created_at, transcript, payload_json
      FROM ${DatabaseConstants.journalEntriesTable}
      WHERE deleted_at IS NULL
        AND is_archived = 0
        AND created_at <= ?
        AND length(trim(transcript)) > 0
      ORDER BY created_at DESC
      LIMIT ?
      ''',
      [cutoff, scanLimit],
    );

    final hour = context.now.toUtc().hour;
    final hits = <ActionableMemoryHit>[];
    for (final row in rows) {
      final id = row['id'] as String? ?? '';
      if (id.isEmpty || locked.contains(id)) continue;
      final transcript = (row['transcript'] as String? ?? '').trim();
      if (transcript.isEmpty) continue;
      final payload = (row['payload_json'] as String? ?? '').toLowerCase();
      final haystack = transcript.toLowerCase();
      final createdMillis = row['created_at'] as int? ?? 0;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdMillis,
        isUtc: true,
      );

      var score = 0;
      var match = ActionableMemoryMatch.timeOfDay;
      if (terms.any(haystack.contains)) {
        score += 4;
        match = ActionableMemoryMatch.words;
      }
      if (place != null &&
          place.isNotEmpty &&
          (haystack.contains(place) || payload.contains(place))) {
        score += 3;
        if (match == ActionableMemoryMatch.timeOfDay) {
          match = ActionableMemoryMatch.place;
        }
      }
      if (calendarTerms.any(haystack.contains)) {
        score += 2;
        if (match == ActionableMemoryMatch.timeOfDay) {
          match = ActionableMemoryMatch.calendar;
        }
      }
      if (createdAt.hour == hour) score += 1;
      if (score == 0 || match == ActionableMemoryMatch.timeOfDay) continue;

      hits.add(
        ActionableMemoryHit(
          entryId: id,
          excerpt: transcript,
          createdAt: createdAt,
          score: score,
          match: match,
        ),
      );
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.createdAt.compareTo(b.createdAt);
    });
    if (hits.length <= resultLimit) return hits;
    return hits.sublist(0, resultLimit);
  }
}
