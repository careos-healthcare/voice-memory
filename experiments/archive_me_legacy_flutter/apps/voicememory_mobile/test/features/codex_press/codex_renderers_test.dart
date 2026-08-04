import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/codex_press/codex_models.dart';
import 'package:voicememory_mobile/features/codex_press/codex_renderers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders bounded PDF, EPUB 3, and self-contained HTML', () async {
    final renderer = const CodexRenderer();
    final manuscript = sampleCodexManuscript();
    final rendered = await renderer.render(manuscript);

    expect(ascii.decode(rendered.pdf.take(5).toList()), '%PDF-');
    final archive = ZipDecoder().decodeBytes(rendered.epub);
    expect(archive.files.first.name, 'mimetype');
    expect(archive.files.first.compression, CompressionType.none);
    expect(
      utf8.decode(archive.findFile('mimetype')!.content as List<int>),
      'application/epub+zip',
    );
    expect(archive.findFile('META-INF/container.xml'), isNotNull);
    expect(archive.findFile('OEBPS/content.opf'), isNotNull);
    expect(archive.findFile('OEBPS/nav.xhtml'), isNotNull);

    final html = utf8.decode(rendered.offlineHtml);
    expect(html, contains('&lt;private&gt;'));
    expect(html, isNot(contains('<script')));
    expect(html, isNot(contains('http://')));
    expect(html, isNot(contains('https://')));
  });
}

CodexManuscript sampleCodexManuscript() => CodexManuscript(
  id: 'codex-test',
  title: 'A <private> memoir',
  template: CodexPublicationTemplate.cinematicMemoir,
  organization: CodexOrganization.chronological,
  generatedAt: DateTime.utc(2026),
  chapters: [
    CodexChapter(
      id: 'chapter-one',
      title: 'Beginnings',
      ordinal: 0,
      start: DateTime.utc(2020),
      end: DateTime.utc(2020, 2),
      passages: [
        CodexPassage(
          heading: 'January',
          text: 'The memory stayed on this device.',
          citations: [
            CodexCitation(
              sourceId: 'journal-1',
              kind: CodexSourceKind.journal,
              occurredAt: DateTime.utc(2020),
              label: 'Journal',
            ),
          ],
        ),
      ],
    ),
  ],
);
