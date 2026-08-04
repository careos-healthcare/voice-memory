import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_chunker.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_models.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_parser_service.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_vault_store.dart';
import 'package:voicememory_mobile/features/document_ingestion/secure_article_fetcher.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('document parsing', () {
    test(
      'preserves Markdown headings, lists, tables, and provenance',
      () async {
        final parsed = await DocumentParserService().parse(
          Uint8List.fromList(
            utf8.encode('''
# Project

First paragraph.

- Alpha
- Beta

| Name | State |
| --- | --- |
| Graph | Ready |
'''),
          ),
          format: DocumentFormat.markdown,
        );

        expect(
          parsed.blocks.map((block) => block.kind),
          containsAll([
            DocumentBlockKind.heading,
            DocumentBlockKind.paragraph,
            DocumentBlockKind.listItem,
            DocumentBlockKind.table,
          ]),
        );
        for (final block in parsed.blocks) {
          expect(
            parsed.text.substring(block.startChar, block.endChar),
            block.text,
          );
        }
      },
    );

    test('reads EPUB package spine order and chapter metadata', () async {
      final parsed = await DocumentParserService().parse(
        _epubFixture(),
        format: DocumentFormat.epub,
      );

      expect(parsed.title, 'Fixture Book');
      expect(parsed.text, contains('Chapter One'));
      expect(
        parsed.text.indexOf('First chapter'),
        lessThan(parsed.text.indexOf('Second chapter')),
      );
      expect(parsed.blocks.first.chapterIndex, 0);
      expect(parsed.blocks.last.chapterIndex, 1);
    });
  });

  test('chunker is deterministic, paragraph-aware, and exactly sourced', () {
    final paragraphs = List.generate(
      8,
      (paragraph) =>
          List.generate(90, (word) => 'p${paragraph}_$word').join(' '),
    );
    final parsed = _parsedParagraphs(paragraphs);
    const chunker = DocumentChunker();

    final first = chunker.chunk(parsed);
    final second = chunker.chunk(parsed);

    expect(first.map((chunk) => chunk.text), second.map((chunk) => chunk.text));
    expect(first, hasLength(2));
    expect(first.first.tokenCount, 450);
    expect(first[1].startChar, lessThan(first.first.endChar));
    for (final chunk in first) {
      expect(chunk.tokenCount, lessThanOrEqualTo(500));
      expect(chunk.text, parsed.text.substring(chunk.startChar, chunk.endChar));
    }
    final overlap = RegExp(r'\S+').allMatches(
      parsed.text.substring(first[1].startChar, first.first.endChar),
    );
    expect(overlap, hasLength(50));
  });

  group('secure article policy', () {
    test('rejects non-HTTPS before network access', () async {
      var resolved = false;
      final fetcher = SecureArticleFetcher(
        resolver: (_) async {
          resolved = true;
          return [InternetAddress('93.184.216.34')];
        },
      );

      await expectLater(
        fetcher.fetch(Uri.parse('http://example.com/article')),
        throwsA(isA<ArticleFetchException>()),
      );
      expect(resolved, isFalse);
    });

    test('rejects DNS results containing private addresses', () async {
      final fetcher = SecureArticleFetcher(
        resolver: (_) async => [
          InternetAddress('93.184.216.34'),
          InternetAddress.loopbackIPv4,
        ],
      );

      await expectLater(
        fetcher.fetch(Uri.parse('https://example.com/article')),
        throwsA(isA<ArticleFetchException>()),
      );
    });

    test('rejects IPv4-mapped IPv6 private addresses', () async {
      final fetcher = SecureArticleFetcher(
        resolver: (_) async => [InternetAddress('::ffff:127.0.0.1')],
      );

      await expectLater(
        fetcher.fetch(Uri.parse('https://example.com/article')),
        throwsA(isA<ArticleFetchException>()),
      );
    });
  });

  group('document vault', () {
    late Directory directory;
    late DocumentVaultStore vault;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('document-vault-');
      vault = DocumentVaultStore(
        directory: directory,
        keyStore: InMemoryPrivateDataEncryptionKeyStore(
          seedKey: List<int>.filled(32, 7),
        ),
        clock: () => DateTime.utc(2026, 7, 28),
      );
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('encrypts metadata and original, then wipes read buffer', () async {
      final bytes = Uint8List.fromList(utf8.encode('private original text'));
      await vault.put(
        metadata: StoredDocumentMetadata(
          id: 'doc-1',
          fileName: 'notes.txt',
          mimeType: 'text/plain',
          byteLength: bytes.length,
          createdAt: DateTime.utc(2026, 7, 27),
        ),
        originalBytes: bytes,
      );

      final disk = await directory
          .list(recursive: true)
          .where((entity) => entity is File)
          .cast<File>()
          .map((file) => file.readAsString())
          .toList();
      expect(disk.join(), isNot(contains('private original text')));
      expect(disk.join(), isNot(contains('notes.txt')));

      Uint8List? retained;
      final value = await vault.withOriginal('doc-1', (clear) async {
        retained = clear;
        return utf8.decode(clear);
      });
      expect(value, 'private original text');
      expect(retained, everyElement(0));
    });

    test('encrypts extracted blocks, chunks, and concept results', () async {
      final metadata = StoredDocumentMetadata(
        id: 'doc-record',
        fileName: 'private.md',
        mimeType: 'text/markdown',
        byteLength: 7,
        createdAt: DateTime.utc(2026, 7, 27),
      );
      final parsed = _parsedParagraphs(['private extracted paragraph']);
      final chunks = const DocumentChunker().chunk(parsed);
      await vault.putRecord(
        StoredDocumentRecord(
          metadata: metadata,
          parsed: parsed,
          chunks: chunks,
          conceptResult: const {
            'concepts': [
              {'id': 'secret-concept'},
            ],
          },
        ),
      );

      final files = await directory
          .list(recursive: true)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      final disk = await Future.wait(files.map((file) => file.readAsString()));
      expect(disk.join(), isNot(contains('private extracted paragraph')));
      expect(disk.join(), isNot(contains('secret-concept')));

      final record = await vault.readRecord(metadata.id);
      expect(record?.parsed.text, parsed.text);
      expect(record?.chunks.single.text, parsed.text);
      expect(record?.conceptResult?['concepts'], isNotEmpty);
    });

    test('deletes blob and retains encrypted tombstone', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      await vault.put(
        metadata: StoredDocumentMetadata(
          id: 'doc-2',
          fileName: 'fixture.bin',
          mimeType: 'application/octet-stream',
          byteLength: bytes.length,
          createdAt: DateTime.utc(2026, 7, 27),
        ),
        originalBytes: bytes,
      );

      await vault.delete('doc-2');

      expect(await vault.withOriginal('doc-2', (_) async => true), isNull);
      expect(await vault.list(), isEmpty);
      final tombstone = (await vault.list(includeTombstones: true)).single;
      expect(tombstone.isDeleted, isTrue);
    });
  });
}

ParsedDocument _parsedParagraphs(List<String> paragraphs) {
  final text = paragraphs.join('\n\n');
  var cursor = 0;
  final blocks = <DocumentBlock>[];
  for (final paragraph in paragraphs) {
    blocks.add(
      DocumentBlock(
        kind: DocumentBlockKind.paragraph,
        text: paragraph,
        startChar: cursor,
        endChar: cursor + paragraph.length,
      ),
    );
    cursor += paragraph.length + 2;
  }
  return ParsedDocument(
    format: DocumentFormat.plainText,
    text: text,
    blocks: blocks,
  );
}

Uint8List _epubFixture() {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<container><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>',
      ),
    )
    ..addFile(
      ArchiveFile.string('OPS/book.opf', '''
<package>
  <metadata><title>Fixture Book</title></metadata>
  <manifest>
    <item id="one" href="one.xhtml"/>
    <item id="two" href="two.xhtml"/>
  </manifest>
  <spine><itemref idref="one"/><itemref idref="two"/></spine>
</package>
'''),
    )
    ..addFile(
      ArchiveFile.string(
        'OPS/one.xhtml',
        '<html><body><h1>Chapter One</h1><p>First chapter.</p></body></html>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OPS/two.xhtml',
        '<html><body><h1>Chapter Two</h1><p>Second chapter.</p></body></html>',
      ),
    );
  return ZipEncoder().encodeBytes(archive);
}
