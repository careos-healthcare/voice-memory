import 'dart:convert';

import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/services/backlog_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('day one json and markdown parse into entries', () {
    final jsonChunks = parseDayOneJsonExport(
      jsonEncode({
        'entries': [
          {
            'uuid': 'river',
            'text': 'walked the river',
            'creationDate': '2024-05-02T08:00:00Z',
          },
        ],
      }),
      sourceFile: 'Journal.json',
    );
    expect(jsonChunks.single.rawText, 'walked the river');
    expect(jsonChunks.single.createdAt, DateTime.utc(2024, 5, 2, 8));

    final markdown = parseMarkdownExport(
      '# Morning\n\nThe river was high.\n\n# Evening\n\nThe market was loud.',
      sourceFile: 'notes.md',
    );
    expect(markdown, hasLength(2));
    expect(markdown.first.rawText, contains('Morning'));
    expect(markdown.last.rawText, contains('The market was loud.'));
  });

  test('the backlog importer accepts json and markdown files', () {
    final service = BacklogImportService(HttpTransport(client: http.Client()));
    final json = utf8.encode(
      jsonEncode({
        'entries': [
          {'text': 'a day one note', 'creationDate': '2024-01-01T00:00:00Z'},
        ],
      }),
    );
    final chunks = service.parseSelectedFiles([
      PlatformFile(name: 'Journal.json', size: json.length, bytes: json),
      PlatformFile(
        name: 'notes.md',
        size: 24,
        bytes: utf8.encode('# Note\n\nHello from markdown.'),
      ),
    ]);
    expect(chunks.map((chunk) => chunk.rawText), [
      'a day one note',
      'Note\n\nHello from markdown.',
    ]);
  });
}
