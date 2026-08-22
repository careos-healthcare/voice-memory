import 'package:archiveme_mobile/features/journal/providers/journal_entity_parse_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseJournalEntryRows', () {
    test('merges compact payload_json with indexed columns', () {
      final rows = [
        {
          'id': 'e1',
          'created_at': DateTime.utc(2026, 1, 10).millisecondsSinceEpoch,
          'updated_at': DateTime.utc(2026, 1, 11).millisecondsSinceEpoch,
          'deleted_at': null,
          'is_archived': 0,
          'transcript': 'indexed transcript',
          'has_verified_proof': 0,
          'payload_json': '''
            {
              "durationSeconds": 42,
              "reflection": {
                "mood": "calm",
                "emotionalIntensity": 2,
                "recurringThemes": [],
                "exactLanguagePattern": "",
                "concreteObservation": "observation",
                "repeatedSignal": ""
              }
            }
          ''',
        },
      ];

      final parsed = parseJournalEntryRows(rows);

      expect(parsed, hasLength(1));
      final entry = parsed['e1']!;
      expect(entry.transcript, 'indexed transcript');
      expect(entry.durationSeconds, 42);
      expect(entry.reflection.concreteObservation, 'observation');
    });

    test('skips rows with invalid payload_json', () {
      final rows = [
        {
          'id': 'bad',
          'created_at': 0,
          'updated_at': 0,
          'deleted_at': null,
          'is_archived': 0,
          'transcript': 'x',
          'has_verified_proof': 0,
          'payload_json': '{not json',
        },
      ];

      expect(parseJournalEntryRows(rows), isEmpty);
    });
  });

  group('parseTaskNodeRows', () {
    test('reads completion flag from payload_json', () {
      final rows = [
        {
          'id': 'task-1',
          'entry_id': 'e1',
          'kind': 'next_action',
          'label': 'Follow up',
          'payload_json': '{"isCompleted": true}',
          'updated_at': DateTime.utc(2026, 2, 1).millisecondsSinceEpoch,
        },
      ];

      final parsed = parseTaskNodeRows(rows);
      expect(parsed['task-1']?.isCompleted, isTrue);
      expect(parsed['task-1']?.label, 'Follow up');
    });
  });
}
