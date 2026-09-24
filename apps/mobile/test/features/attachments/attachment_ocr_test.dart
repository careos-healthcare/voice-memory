import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/attachments/attachment_ingestion.dart';
import 'package:archiveme_mobile/features/attachments/local_ocr_processor.dart';
import 'package:archiveme_mobile/features/attachments/widgets/attachment_viewer_widget.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_023_attachment_text.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ml kit blocks keep bounds and confidence', () {
    final page = ocrDocumentFromMlKit(
      text: '',
      blocks: const [
        MlKitTextBlock(
          text: 'Met Ada',
          left: 4,
          top: 8,
          right: 40,
          bottom: 24,
          lines: ['Met Ada'],
          confidence: 0.92,
        ),
      ],
    );

    expect(page.text, 'Met Ada');
    expect(page.blocks.single.bounds.left, 4);
    expect(page.blocks.single.lines, ['Met Ada']);
    expect(page.confidence, closeTo(0.92, 0.001));
  });

  test('photos stay unread while capture is off', () async {
    var calls = 0;
    final processor = LocalOcrProcessor(
      photosEnabled: false,
      recognize: (bytes) async {
        calls++;
        return OcrDocument.empty;
      },
    );

    final page = await processor.processBytes(Uint8List.fromList([1]));

    expect(page.text, isEmpty);
    expect(calls, 0);
  });

  test('ocr text is embedded and linked to people and places', () async {
    final directory = await Directory.systemTemp.createTemp('attachment-ocr');
    final app = await openTestAppSqliteDatabase(
      filePath: '${directory.path}/archive.db',
    );
    addTearDown(() async {
      await app.close();
      AppSqliteDatabase.resetForTest();
    });
    final db = app.database;
    await db.insert('journal_entries', {
      'id': 'moment-1',
      'created_at': 1,
      'updated_at': 1,
      'is_archived': 0,
      'transcript': 'Voice note',
      'has_verified_proof': 0,
      'payload_json': '{}',
    });

    final result =
        await AttachmentOcrIngestion(
          processor: LocalOcrProcessor(
            photosEnabled: true,
            recognize: (bytes) async => ocrDocumentFromMlKit(
              text:
                  'Met Ada at Banstead. I want to finish the project milestone.',
              blocks: const [
                MlKitTextBlock(
                  text: 'Met Ada at Banstead.',
                  left: 1,
                  top: 2,
                  right: 30,
                  bottom: 12,
                  confidence: 0.88,
                ),
              ],
            ),
          ),
        ).ingest(
          db: db,
          entryId: 'moment-1',
          imageBytes: Uint8List.fromList([9]),
          filePath: 'scans/page.png',
        );

    final entry = await db.query(
      'journal_entries',
      columns: [Migration023AttachmentText.column],
      where: 'id = ?',
      whereArgs: ['moment-1'],
    );
    expect(
      entry.single[Migration023AttachmentText.column],
      contains('Banstead'),
    );
    expect(result.vectorHit?.id, 'moment-1');
    expect(result.vectorHit?.score, closeTo(1, 0.001));
    expect(result.entityIds, contains('people:ada'));
    expect(result.entityIds, contains('locations:banstead'));
    expect(result.entityIds, contains('goals:finish-the-project-milestone'));
    final linked = await db.query(
      Migration023AttachmentText.attachmentsTable,
      where: 'entry_id = ?',
      whereArgs: ['moment-1'],
    );
    expect(linked.single['file_path'], 'scans/page.png');
    expect(linked.single['embedding'], isNotNull);
  });

  testWidgets('extracted text highlights a search term from the photo', (
    tester,
  ) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentViewerWidget(
            imageBytes: png,
            transcript: 'Voice note',
            searchTerms: const ['Ada'],
            blocks: const [
              OcrTextBlock(
                text: 'Met Ada at Banstead',
                bounds: OcrBoundingBox(left: 0, top: 0, right: 10, bottom: 10),
                confidence: 0.9,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('attachment_image')), findsOneWidget);
    expect(find.text('Voice note'), findsOneWidget);

    await tester.tap(find.text('Extracted Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attachment_ocr_chip_0')));
    await tester.pump();

    expect(_highlightedText(tester), 'Ada');

    await tester.tap(find.byKey(const Key('attachment_ocr_body')));
    await tester.pump();
    expect(_highlightedText(tester), isNull);
  });
}

String? _highlightedText(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find.descendant(
      of: find.byKey(const Key('attachment_ocr_body')),
      matching: find.byType(RichText),
    ),
  );
  final root = rich.text as TextSpan;
  for (final span in root.children ?? const <InlineSpan>[]) {
    if (span is TextSpan &&
        span.style?.backgroundColor == AppTokens.primary200) {
      return span.text;
    }
  }
  return null;
}
