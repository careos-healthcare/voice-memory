import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as markdown;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'document_models.dart';

class DocumentParseException implements Exception {
  const DocumentParseException(this.message);

  final String message;

  @override
  String toString() => 'DocumentParseException: $message';
}

abstract interface class DocumentParserAdapter {
  DocumentFormat get format;

  Future<ParsedDocument> parse(Uint8List bytes, {String? sourceName});
}

final class DocumentParserService {
  DocumentParserService({Iterable<DocumentParserAdapter>? adapters})
    : _adapters = {
        for (final adapter in adapters ?? _defaultAdapters)
          adapter.format: adapter,
      };

  static final List<DocumentParserAdapter> _defaultAdapters = [
    PdfDocumentParser(),
    EpubDocumentParser(),
    MarkdownDocumentParser(),
    HtmlDocumentParser(),
    PlainTextDocumentParser(),
  ];

  final Map<DocumentFormat, DocumentParserAdapter> _adapters;

  Future<ParsedDocument> parse(
    Uint8List bytes, {
    required DocumentFormat format,
    String? sourceName,
  }) {
    final adapter = _adapters[format];
    if (adapter == null) {
      throw DocumentParseException('No parser registered for ${format.name}.');
    }
    return adapter.parse(bytes, sourceName: sourceName);
  }
}

final class PlainTextDocumentParser implements DocumentParserAdapter {
  @override
  DocumentFormat get format => DocumentFormat.plainText;

  @override
  Future<ParsedDocument> parse(Uint8List bytes, {String? sourceName}) async {
    final source = _decodeText(bytes);
    final builder = _DocumentBuilder(format);
    for (final paragraph in source.split(RegExp(r'\n\s*\n'))) {
      builder.add(DocumentBlockKind.paragraph, _normalizeInline(paragraph));
    }
    return builder.build();
  }
}

final class HtmlDocumentParser implements DocumentParserAdapter {
  @override
  DocumentFormat get format => DocumentFormat.html;

  @override
  Future<ParsedDocument> parse(Uint8List bytes, {String? sourceName}) async {
    return parseHtml(_decodeText(bytes));
  }

  ParsedDocument parseHtml(
    String source, {
    DocumentFormat outputFormat = DocumentFormat.html,
    int? chapterIndex,
    String? chapterTitle,
  }) {
    final document = html_parser.parse(source);
    final builder = _DocumentBuilder(outputFormat);
    final body = document.body ?? document.documentElement;
    if (body != null) {
      _appendHtmlBlocks(
        body,
        builder,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
      );
    }
    final title = _normalizeInline(document.querySelector('title')?.text ?? '');
    return builder.build(title: title.isEmpty ? null : title);
  }
}

final class MarkdownDocumentParser implements DocumentParserAdapter {
  @override
  DocumentFormat get format => DocumentFormat.markdown;

  @override
  Future<ParsedDocument> parse(Uint8List bytes, {String? sourceName}) async {
    final html = markdown.markdownToHtml(
      _decodeText(bytes),
      extensionSet: markdown.ExtensionSet.gitHubWeb,
    );
    return HtmlDocumentParser().parseHtml(
      html,
      outputFormat: DocumentFormat.markdown,
    );
  }
}

final class PdfDocumentParser implements DocumentParserAdapter {
  @override
  DocumentFormat get format => DocumentFormat.pdf;

  @override
  Future<ParsedDocument> parse(Uint8List bytes, {String? sourceName}) async {
    final document = await PdfDocument.openData(
      Uint8List.fromList(bytes),
      sourceName: sourceName ?? 'document-ingestion.pdf',
    );
    try {
      final builder = _DocumentBuilder(format);
      for (final page in document.pages) {
        final raw = await page.loadText();
        final text = _normalizeMultiline(raw?.fullText ?? '');
        if (text.isNotEmpty) {
          for (final paragraph in text.split(RegExp(r'\n\s*\n'))) {
            builder.add(
              DocumentBlockKind.paragraph,
              paragraph,
              pageNumber: page.pageNumber,
            );
          }
        }
      }
      return builder.build();
    } finally {
      await document.dispose();
    }
  }
}

final class EpubDocumentParser implements DocumentParserAdapter {
  @override
  DocumentFormat get format => DocumentFormat.epub;

  @override
  Future<ParsedDocument> parse(Uint8List bytes, {String? sourceName}) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw const DocumentParseException('Invalid EPUB archive.');
    }
    final entries = <String, ArchiveFile>{
      for (final file in archive.files)
        if (file.isFile) _archivePath(file.name): file,
    };
    final container = entries['META-INF/container.xml'];
    if (container == null) {
      throw const DocumentParseException('EPUB container is missing.');
    }
    final containerDocument = html_parser.parse(_entryText(container));
    final rootfile = containerDocument.querySelector('rootfile');
    final opfPath = rootfile?.attributes['full-path'];
    if (opfPath == null || !_safeArchivePath(opfPath)) {
      throw const DocumentParseException('EPUB package path is invalid.');
    }
    final normalizedOpfPath = _archivePath(opfPath);
    final package = entries[normalizedOpfPath];
    if (package == null) {
      throw const DocumentParseException('EPUB package is missing.');
    }
    final packageDocument = html_parser.parse(_entryText(package));
    final manifest = <String, String>{};
    for (final item in packageDocument.querySelectorAll('manifest item')) {
      final id = item.attributes['id'];
      final href = item.attributes['href'];
      if (id != null && href != null) manifest[id] = href;
    }
    final title = _normalizeInline(
      packageDocument.querySelector('metadata title')?.text ?? '',
    );
    final builder = _DocumentBuilder(format);
    final base = p.posix.dirname(normalizedOpfPath);
    var chapterIndex = 0;
    for (final itemref in packageDocument.querySelectorAll('spine itemref')) {
      final href = manifest[itemref.attributes['idref']];
      if (href == null) continue;
      final chapterPath = _archivePath(
        p.posix.normalize(p.posix.join(base, href)),
      );
      if (!_safeArchivePath(chapterPath)) {
        throw const DocumentParseException('Unsafe EPUB chapter path.');
      }
      final chapter = entries[chapterPath];
      if (chapter == null) continue;
      final chapterDocument = html_parser.parse(_entryText(chapter));
      final body = chapterDocument.body ?? chapterDocument.documentElement;
      if (body == null) continue;
      final chapterTitle = _normalizeInline(
        chapterDocument.querySelector('h1, h2, title')?.text ?? '',
      );
      _appendHtmlBlocks(
        body,
        builder,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle.isEmpty ? null : chapterTitle,
      );
      chapterIndex++;
    }
    return builder.build(title: title.isEmpty ? null : title);
  }
}

void _appendHtmlBlocks(
  dom.Element root,
  _DocumentBuilder builder, {
  int? chapterIndex,
  String? chapterTitle,
}) {
  const selectors = 'h1,h2,h3,h4,h5,h6,p,li,table';
  for (final element in root.querySelectorAll(selectors)) {
    if (_hasAncestor(element, 'table') && element.localName != 'table') {
      continue;
    }
    final tag = element.localName;
    if (tag == 'table') {
      final rows = element
          .querySelectorAll('tr')
          .map((row) {
            return row
                .querySelectorAll('th,td')
                .map((cell) => _normalizeInline(cell.text))
                .join(' | ');
          })
          .where((row) => row.isNotEmpty);
      builder.add(
        DocumentBlockKind.table,
        rows.join('\n'),
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
      );
    } else {
      final text = _normalizeInline(element.text);
      final headingLevel = tag != null && RegExp(r'^h[1-6]$').hasMatch(tag)
          ? int.parse(tag.substring(1))
          : null;
      builder.add(
        headingLevel != null
            ? DocumentBlockKind.heading
            : tag == 'li'
            ? DocumentBlockKind.listItem
            : DocumentBlockKind.paragraph,
        text,
        headingLevel: headingLevel,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
      );
    }
  }
}

bool _hasAncestor(dom.Element element, String tag) {
  dom.Element? parent = element.parent;
  while (parent != null) {
    if (parent.localName == tag) return true;
    parent = parent.parent;
  }
  return false;
}

final class _DocumentBuilder {
  _DocumentBuilder(this.format);

  final DocumentFormat format;
  final StringBuffer _text = StringBuffer();
  final List<DocumentBlock> _blocks = [];
  int _length = 0;

  void add(
    DocumentBlockKind kind,
    String text, {
    int? headingLevel,
    int? pageNumber,
    int? chapterIndex,
    String? chapterTitle,
  }) {
    final normalized = _normalizeMultiline(text);
    if (normalized.isEmpty) return;
    if (_length > 0) {
      _text.write('\n\n');
      _length += 2;
    }
    final start = _length;
    _text.write(normalized);
    _length += normalized.length;
    _blocks.add(
      DocumentBlock(
        kind: kind,
        text: normalized,
        startChar: start,
        endChar: _length,
        headingLevel: headingLevel,
        pageNumber: pageNumber,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
      ),
    );
  }

  ParsedDocument build({String? title}) => ParsedDocument(
    format: format,
    text: _text.toString(),
    blocks: _blocks,
    title: title,
  );
}

String _decodeText(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

String _entryText(ArchiveFile file) => _decodeText(file.content);

String _normalizeInline(String source) =>
    source.replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalizeMultiline(String source) => source
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .split('\n')
    .map((line) => _normalizeInline(line))
    .join('\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

String _archivePath(String value) => p.posix
    .normalize(value.replaceAll('\\', '/'))
    .replaceFirst(RegExp(r'^/'), '');

bool _safeArchivePath(String value) {
  final normalized = _archivePath(value);
  return normalized.isNotEmpty &&
      normalized != '..' &&
      !normalized.startsWith('../') &&
      !p.posix.isAbsolute(value);
}
