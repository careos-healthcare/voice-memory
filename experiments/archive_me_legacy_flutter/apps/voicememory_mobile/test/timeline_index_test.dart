import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/timeline/timeline_index.dart';
import 'package:voicememory_mobile/features/timeline/timeline_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, DateTime createdAt) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: 'Entry $id',
    durationSeconds: 30,
    reflection: Reflection.fromJson(const {}),
  );
}

void main() {
  test('buildTimelineRows groups by year and month newest first', () {
    final rows = buildTimelineRows([
      _entry('a', DateTime(2026, 5, 10)),
      _entry('b', DateTime(2026, 5, 2)),
      _entry('c', DateTime(2026, 4, 20)),
      _entry('d', DateTime(2025, 12, 1)),
    ]);

    expect(rows[0], isA<TimelineYearRow>());
    expect((rows[0] as TimelineYearRow).year, 2026);

    expect(rows[1], isA<TimelineMonthRow>());
    final may = rows.whereType<TimelineMonthRow>().first;
    expect(may.month, 5);
    expect(may.recordingCount, 2);

    expect(rows[2], isA<TimelineEntryRow>());
    expect(rows[3], isA<TimelineEntryRow>());

    final april = rows.whereType<TimelineMonthRow>().elementAt(1);
    expect(april.month, 4);
    expect(april.recordingCount, 1);

    expect(
      rows.whereType<TimelineYearRow>().any((r) => r.year == 2025),
      isTrue,
    );
  });

  test('buildTimelineRows returns empty for no entries', () {
    expect(buildTimelineRows([]), isEmpty);
  });
}
