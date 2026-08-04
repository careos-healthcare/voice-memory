import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_models.dart';
import 'package:voicememory_mobile/features/document_ingestion/ui/document_vault_sheet.dart';

void main() {
  testWidgets('HTTPS URL requires explicit fetch confirmation', (tester) async {
    Uri? fetched;
    final controller = DocumentVaultController(
      onImportUrl: (uri, report) async {
        fetched = uri;
        return _entry();
      },
    );
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    await tester.tap(find.byKey(const Key('document-import-url')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('document-url-input')),
      'https://example.com/article',
    );
    await tester.tap(find.byKey(const Key('document-url-review')));
    await tester.pumpAndSettle();

    expect(fetched, isNull);
    expect(find.byKey(const Key('document-url-confirmation')), findsOneWidget);
    expect(find.textContaining('https://example.com/article'), findsOneWidget);

    await tester.tap(find.byKey(const Key('document-url-fetch-confirm')));
    await tester.pumpAndSettle();
    expect(fetched, Uri.parse('https://example.com/article'));
  });

  testWidgets('shows import progress and failure state', (tester) async {
    final controller = DocumentVaultController();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    controller.reportImportProgress(.45, 'Parsing locally');
    await tester.pump();
    expect(find.text('Parsing locally'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, .45);

    controller.reportImportFailure('Unsupported document');
    await tester.pump();
    expect(find.text('Unsupported document'), findsOneWidget);
  });

  testWidgets('selection requires cloud approval before analysis', (
    tester,
  ) async {
    var analyses = 0;
    List<DocumentChunk>? approved;
    final controller = DocumentVaultController(
      documents: [_entry()],
      onAnalyzeSelected: (document, selected, report) async {
        analyses++;
        approved = selected;
        return _entry(cloudAnalyzed: true);
      },
    );
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    await tester.tap(find.byKey(const Key('document-paragraph-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('document-analyze-selected')));
    await tester.pumpAndSettle();

    expect(analyses, 0);
    expect(find.byKey(const Key('document-cloud-approval')), findsOneWidget);
    expect(
      find.textContaining('original document stays local'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('document-cloud-approve')));
    await tester.pumpAndSettle();
    expect(analyses, 1);
    expect(approved, hasLength(1));
    expect(find.text('Approved excerpts: cloud'), findsOneWidget);
  });

  testWidgets('secure deletion is confirmed before callback', (tester) async {
    var deleted = false;
    final controller = DocumentVaultController(
      documents: [_entry()],
      onDelete: (_) async => deleted = true,
    );
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    await tester.tap(find.byKey(const Key('document-secure-delete')));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    expect(
      find.byKey(const Key('document-delete-confirmation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('document-delete-approve')));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(
      find.text('No documents yet.\nFiles remain encrypted locally.'),
      findsOneWidget,
    );
  });

  testWidgets('reader marker backgrounds sheet and focuses graph target', (
    tester,
  ) async {
    var backgrounded = false;
    String? focusedNode;
    final controller = DocumentVaultController(
      documents: [
        _entry(
          markers: const [
            DocumentReaderMarker(
              id: 'citation-1',
              kind: DocumentMarkerKind.citation,
              label: 'Memory citation',
              blockIndex: 0,
              nodeId: 'node-42',
            ),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller,
      onBackgroundRequested: () => backgrounded = true,
      onFocusNode: (id) => focusedNode = id,
    );

    await tester.tap(find.byKey(const Key('document-marker-citation-1')));
    expect(backgrounded, isTrue);
    expect(focusedNode, 'node-42');
  });
}

Future<void> _pump(
  WidgetTester tester,
  DocumentVaultController controller, {
  VoidCallback? onBackgroundRequested,
  ValueChanged<String>? onFocusNode,
}) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DocumentVaultSheet(
          controller: controller,
          onClose: () {},
          onBackgroundRequested: onBackgroundRequested,
          onFocusNode: onFocusNode,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DocumentVaultEntry _entry({
  bool cloudAnalyzed = false,
  List<DocumentReaderMarker> markers = const [],
}) {
  const text = 'A safe local paragraph about memory and attention.';
  final parsed = ParsedDocument(
    format: DocumentFormat.plainText,
    text: text,
    blocks: [
      DocumentBlock(
        kind: DocumentBlockKind.paragraph,
        text: text,
        startChar: 0,
        endChar: text.length,
      ),
    ],
    title: 'Fixture',
  );
  return DocumentVaultEntry(
    metadata: StoredDocumentMetadata(
      id: 'document_123',
      fileName: 'fixture.txt',
      mimeType: 'text/plain',
      byteLength: Uint8List.fromList(text.codeUnits).length,
      createdAt: DateTime.utc(2026, 7, 28),
    ),
    parsed: parsed,
    chunks: [
      DocumentChunk(
        index: 0,
        text: text,
        startChar: 0,
        endChar: text.length,
        tokenCount: 8,
        pageNumbers: const [],
        chapterIndexes: const [],
      ),
    ],
    cloudAnalyzed: cloudAnalyzed,
    markers: markers,
  );
}
