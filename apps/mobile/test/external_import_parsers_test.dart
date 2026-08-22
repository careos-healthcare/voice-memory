import 'package:archiveme_mobile/features/import/apple_notes_json_parser.dart';
import 'package:archiveme_mobile/features/import/day_one_json_parser.dart';
import 'package:archiveme_mobile/features/import/journal_entry_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DayOneJsonParser extracts entries with timestamps', () {
    const json = '''
{
  "entries": [
    {
      "uuid": "dayone-1",
      "creationDate": "2026-01-10T09:00:00.000Z",
      "text": "First Day One entry"
    }
  ]
}
''';
    final records = DayOneJsonParser.parse(json, sourceFile: 'dayone.json');
    expect(records, hasLength(1));
    expect(records.first.text, 'First Day One entry');
    expect(records.first.externalId, 'dayone-1');
  });

  test('AppleNotesJsonParser extracts note title and body', () {
    const json = '''
{
  "notes": [
    {
      "id": "note-1",
      "title": "Morning",
      "body": "Coffee and planning",
      "createdAt": "2026-02-01T08:30:00.000Z"
    }
  ]
}
''';
    final records = AppleNotesJsonParser.parse(json, sourceFile: 'notes.json');
    expect(records, hasLength(1));
    expect(records.first.text, contains('Morning'));
    expect(records.first.text, contains('Coffee and planning'));
  });

  test('JournalEntryImporter marks captureSource import', () {
    final entry = JournalEntryImporter.toJournalEntry(
      AppleNotesJsonParser.parse(
        '{"notes":[{"body":"Imported note"}]}',
        sourceFile: 'notes.json',
      ).first,
    );
    expect(entry.captureSource, 'import');
    expect(entry.transcript, 'Imported note');
  });
}