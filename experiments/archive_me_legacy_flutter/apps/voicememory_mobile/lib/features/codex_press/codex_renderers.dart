import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'codex_models.dart';

final class CodexRenderer {
  const CodexRenderer();

  static const maximumArtifactBytes = 64 * 1024 * 1024;

  Future<CodexRenderedArtifacts> render(CodexManuscript manuscript) async {
    final artifacts = CodexRenderedArtifacts(
      pdf: await renderPdf(manuscript),
      epub: renderEpub(manuscript),
      offlineHtml: renderHtml(manuscript),
    );
    for (final bytes in [
      artifacts.pdf,
      artifacts.epub,
      artifacts.offlineHtml,
    ]) {
      if (bytes.length > maximumArtifactBytes) {
        throw const FormatException('Rendered Codex artifact is too large.');
      }
    }
    return artifacts;
  }

  Future<Uint8List> renderPdf(CodexManuscript manuscript) async {
    final style = _style(manuscript.template);
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSerif.ttf'),
    );
    final document = pw.Document(
      title: manuscript.title,
      author: 'ArchiveMe — local Codex Press',
      subject: 'Offline private memoir',
      creator: 'ArchiveMe Codex Press',
      compress: true,
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(52, 56, 52, 56),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  manuscript.title,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 90),
          pw.Text(
            manuscript.title,
            style: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              fontSize: style.titleSize,
              color: style.pdfColor,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            manuscript.template.label,
            style: pw.TextStyle(
              font: font,
              fontStyle: pw.FontStyle.italic,
              fontSize: 13,
            ),
          ),
          pw.SizedBox(height: 70),
          pw.Text(
            'Compiled privately on this device\n'
            '${manuscript.generatedAt.toIso8601String().substring(0, 10)}',
          ),
          pw.NewPage(),
          pw.Header(level: 0, text: 'Contents'),
          ...manuscript.chapters.map(
            (chapter) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text('${chapter.ordinal + 1}. ${chapter.title}'),
            ),
          ),
          for (final chapter in manuscript.chapters) ...[
            pw.NewPage(),
            pw.Header(
              level: 0,
              child: pw.Text(
                chapter.title,
                style: pw.TextStyle(
                  font: font,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: style.chapterSize,
                  color: style.pdfColor,
                ),
              ),
            ),
            pw.Text(
              '${_date(chapter.start)} — ${_date(chapter.end)}',
              style: pw.TextStyle(
                font: font,
                fontStyle: pw.FontStyle.italic,
                fontSize: 9,
              ),
            ),
            pw.SizedBox(height: 12),
            for (final passage in chapter.passages) ...[
              pw.Header(level: 2, text: passage.heading),
              pw.Text(
                passage.text,
                style: pw.TextStyle(
                  font: font,
                  fontSize: style.bodySize,
                  lineSpacing: 3,
                ),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                passage.citations
                    .map(
                      (citation) =>
                          '${citation.kind.name}: ${citation.sourceId} · '
                          '${_date(citation.occurredAt)}',
                    )
                    .join('\n'),
                style: pw.TextStyle(
                  font: font,
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
    return document.save();
  }

  Uint8List renderEpub(CodexManuscript manuscript) {
    final archive = Archive();
    final mime = ArchiveFile.string('mimetype', 'application/epub+zip')
      ..compression = CompressionType.none;
    archive.addFile(mime);
    archive.addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<?xml version="1.0"?>'
            '<container version="1.0" '
            'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="OEBPS/content.opf" '
            'media-type="application/oebps-package+xml"/></rootfiles></container>',
      ),
    );
    archive.addFile(
      ArchiveFile.string('OEBPS/styles.css', _css(manuscript.template)),
    );
    archive.addFile(
      ArchiveFile.string('OEBPS/nav.xhtml', _epubNavigation(manuscript)),
    );
    for (final chapter in manuscript.chapters) {
      archive.addFile(
        ArchiveFile.string(
          'OEBPS/chapter-${chapter.ordinal + 1}.xhtml',
          _chapterXhtml(manuscript, chapter),
        ),
      );
    }
    archive.addFile(
      ArchiveFile.string('OEBPS/content.opf', _contentOpf(manuscript)),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Uint8List renderHtml(CodexManuscript manuscript) => Uint8List.fromList(
    utf8.encode('''
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="generator" content="ArchiveMe Local Codex Press">
<title>${_html(manuscript.title)}</title><style>${_css(manuscript.template)}</style>
</head><body><main><header><h1>${_html(manuscript.title)}</h1>
<p>${_html(manuscript.template.label)} · compiled privately on this device</p>
</header><nav aria-label="Contents"><h2>Contents</h2><ol>
${manuscript.chapters.map((chapter) => '<li><a href="#${_id(chapter.id)}">${_html(chapter.title)}</a></li>').join()}
</ol></nav>
${manuscript.chapters.map(_htmlChapter).join()}
</main></body></html>
'''),
  );

  String _epubNavigation(CodexManuscript manuscript) =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml"
xmlns:epub="http://www.idpf.org/2007/ops" lang="en"><head>
<title>${_xml(manuscript.title)}</title><link rel="stylesheet" href="styles.css"/>
</head><body><nav epub:type="toc"><h1>Contents</h1><ol>
${manuscript.chapters.map((chapter) => '<li><a href="chapter-${chapter.ordinal + 1}.xhtml">${_xml(chapter.title)}</a></li>').join()}
</ol></nav></body></html>''';

  String _chapterXhtml(CodexManuscript manuscript, CodexChapter chapter) =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head><title>${_xml(chapter.title)}</title><link rel="stylesheet" href="styles.css"/></head>
<body>${_htmlChapter(chapter)}</body></html>''';

  String _contentOpf(CodexManuscript manuscript) {
    final modified = manuscript.generatedAt
        .toUtc()
        .toIso8601String()
        .split('.')
        .first;
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0"
unique-identifier="book-id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="book-id">${_xml(manuscript.id)}</dc:identifier>
<dc:title>${_xml(manuscript.title)}</dc:title><dc:language>en</dc:language>
<dc:creator>ArchiveMe Local Codex Press</dc:creator>
<meta property="dcterms:modified">${modified}Z</meta></metadata><manifest>
<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
<item id="css" href="styles.css" media-type="text/css"/>
${manuscript.chapters.map((chapter) => '<item id="c${chapter.ordinal + 1}" href="chapter-${chapter.ordinal + 1}.xhtml" media-type="application/xhtml+xml"/>').join()}
</manifest><spine>
${manuscript.chapters.map((chapter) => '<itemref idref="c${chapter.ordinal + 1}"/>').join()}
</spine></package>''';
  }

  String _htmlChapter(CodexChapter chapter) =>
      '''
<article id="${_id(chapter.id)}"><h2>${_html(chapter.title)}</h2>
<p class="dates">${_date(chapter.start)} — ${_date(chapter.end)}</p>
${chapter.passages.map((passage) => '<section><h3>${_html(passage.heading)}</h3><p>${_html(passage.text).replaceAll('\n', '<br/>')}</p><footer>${passage.citations.map((citation) => '${_html(citation.kind.name)}: ${_html(citation.sourceId)} · ${_date(citation.occurredAt)}').join('<br/>')}</footer></section>').join()}
</article>''';

  static String _css(CodexPublicationTemplate template) {
    final style = _style(template);
    return '''
:root{color-scheme:light dark}body{margin:0;background:${style.background};
color:${style.foreground};font-family:Georgia,serif;line-height:1.65}
main{max-width:760px;margin:auto;padding:4rem 2rem}h1,h2,h3{font-family:Arial,sans-serif;
letter-spacing:${style.letterSpacing}}h1{font-size:3rem}h2{margin-top:4rem;
border-bottom:1px solid ${style.accent};padding-bottom:.5rem}a{color:${style.accent}}
section{margin:2rem 0}footer,.dates{font-size:.78rem;opacity:.72}
@media print{nav{page-break-after:always}article{page-break-before:always}}
''';
  }

  static _CodexStyle _style(CodexPublicationTemplate template) =>
      switch (template) {
        CodexPublicationTemplate.minimalistJournal => const _CodexStyle(
          titleSize: 36,
          chapterSize: 24,
          bodySize: 11,
          background: '#faf9f6',
          foreground: '#202020',
          accent: '#666666',
          letterSpacing: '0',
          pdfColor: PdfColors.grey900,
        ),
        CodexPublicationTemplate.academicMonograph => const _CodexStyle(
          titleSize: 32,
          chapterSize: 21,
          bodySize: 10,
          background: '#ffffff',
          foreground: '#111827',
          accent: '#374151',
          letterSpacing: '.02em',
          pdfColor: PdfColors.blueGrey900,
        ),
        CodexPublicationTemplate.cinematicMemoir => const _CodexStyle(
          titleSize: 40,
          chapterSize: 25,
          bodySize: 11,
          background: '#f7f2e8',
          foreground: '#2f241d',
          accent: '#8b5e3c',
          letterSpacing: '.04em',
          pdfColor: PdfColors.brown800,
        ),
        CodexPublicationTemplate.cyberpunkChronicle => const _CodexStyle(
          titleSize: 38,
          chapterSize: 23,
          bodySize: 10,
          background: '#0b1020',
          foreground: '#e5f9ff',
          accent: '#00b8d4',
          letterSpacing: '.08em',
          pdfColor: PdfColors.cyan800,
        ),
      };

  static String _date(DateTime value) =>
      value.toUtc().toIso8601String().substring(0, 10);
  static String _id(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');
  static String _html(String value) => _xml(value).replaceAll("'", '&#39;');
  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

final class _CodexStyle {
  const _CodexStyle({
    required this.titleSize,
    required this.chapterSize,
    required this.bodySize,
    required this.background,
    required this.foreground,
    required this.accent,
    required this.letterSpacing,
    required this.pdfColor,
  });

  final double titleSize;
  final double chapterSize;
  final double bodySize;
  final String background;
  final String foreground;
  final String accent;
  final String letterSpacing;
  final PdfColor pdfColor;
}
