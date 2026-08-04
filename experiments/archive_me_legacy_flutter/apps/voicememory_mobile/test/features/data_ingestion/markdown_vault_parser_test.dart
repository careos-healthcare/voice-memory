import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/data_ingestion/markdown_vault_parser.dart';

void main() {
  test('extracts YAML frontmatter and Obsidian wiki links', () {
    const parser = MarkdownVaultParser();
    final note = parser.parseText('''
---
title: "Project Atlas"
tags:
  - work
  - research
aliases: [Atlas, "Project A"]
created: 2025-03-14T09:30:00Z
---
Atlas depends on [[Research Notes|the research]] and [[Roadmap#Milestones]].
''', relativePath: 'Projects/Atlas.md');

    expect(note.title, 'Project Atlas');
    expect(note.tags, ['research', 'work']);
    expect(note.aliases, ['Atlas', 'Project A']);
    expect(note.createdAt, DateTime.utc(2025, 3, 14, 9, 30));
    expect(note.links.map((link) => link.target), [
      'Research Notes',
      'Roadmap',
    ]);
    expect(note.links.first.alias, 'the research');
    expect(note.contentHash, hasLength(64));
  });

  test(
    'parses local Notion markdown links and recursively orders files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'markdown-vault-test-',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      await Directory('${root.path}/Nested').create();
      await File(
        '${root.path}/Nested/B.md',
      ).writeAsString('See [Alpha](../A.md) and [[A]].');
      await File('${root.path}/A.md').writeAsString('# Alpha');
      await File('${root.path}/ignored.txt').writeAsString('not markdown');

      final progress = <int>[];
      final notes = await const MarkdownVaultParser().parseDirectory(
        root,
        onProgress: (value) => progress.add(value.parsedFiles),
      );

      expect(notes.map((note) => note.relativePath), ['A.md', 'Nested/B.md']);
      expect(notes.last.links.map((link) => link.target), ['A']);
      expect(progress, [1, 2]);
    },
  );
}
