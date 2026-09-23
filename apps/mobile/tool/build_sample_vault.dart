import 'dart:io';

import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:sqlite3/sqlite3.dart';

/// Source rows for the shipped sample vault.
const sampleVaultRows = <({String id, String theme, String title, String body})>[
  (
    id: 'career-review',
    theme: 'career',
    title: 'Monday review',
    body:
        'The Monday review made me anxious about work. I kept rewriting the launch note.',
  ),
  (
    id: 'career-call',
    theme: 'career',
    title: 'Client call',
    body:
        'I felt anxious before the client call and worried the work timeline would slip.',
  ),
  (
    id: 'career-budget',
    theme: 'career',
    title: 'Budget meeting',
    body:
        'Work felt heavy after the budget meeting. I left unsure about the role.',
  ),
  (
    id: 'career-quarter',
    theme: 'career',
    title: 'Quarter close',
    body: 'Grateful for the team after we closed the quarter. Work felt lighter.',
  ),
  (
    id: 'career-interview',
    theme: 'career',
    title: 'Job interview',
    body:
        'The job interview left me anxious about work and hopeful about a change.',
  ),
  (
    id: 'project-prototype',
    theme: 'projects',
    title: 'Garden app',
    body:
        'Project milestone: the first prototype of the garden app ran on my phone.',
  ),
  (
    id: 'project-reading',
    theme: 'projects',
    title: 'Reading list',
    body: 'Shipped the reading list project milestone after three quiet weekends.',
  ),
  (
    id: 'project-photos',
    theme: 'projects',
    title: 'Photo archive',
    body: 'Personal project milestone: finished the photo archive export.',
  ),
  (
    id: 'project-writing',
    theme: 'projects',
    title: 'Writing project',
    body:
        'Started a small writing project. The first chapter is a milestone I wanted.',
  ),
  (
    id: 'project-bookshelf',
    theme: 'projects',
    title: 'Bookshelf',
    body: 'Built the bookshelf project and marked the paint job as a milestone.',
  ),
  (
    id: 'wellness-sleep',
    theme: 'health',
    title: 'Long walk',
    body: 'A long walk helped my sleep. I felt calmer by evening.',
  ),
  (
    id: 'wellness-stretch',
    theme: 'health',
    title: 'Morning stretch',
    body: 'Skipped the morning stretch and my back felt tight all day.',
  ),
  (
    id: 'wellness-meals',
    theme: 'health',
    title: 'Home cooking',
    body: 'I cooked at home and felt better after a week of rushed meals.',
  ),
  (
    id: 'wellness-rest',
    theme: 'health',
    title: 'Rest day',
    body: 'Rest day. No meetings, just a slow walk, earlier sleep, and an early night.',
  ),
  (
    id: 'wellness-evening',
    theme: 'health',
    title: 'Evening routine',
    body:
        'A quieter evening routine: more water, earlier sleep, and less scrolling.',
  ),
];

void main() {
  final file = File('assets/sample_vault/sample_vault.db');
  file.parent.createSync(recursive: true);
  if (file.existsSync()) file.deleteSync();
  final db = sqlite3.open(file.path)
    ..execute('''
    CREATE TABLE sample_entries (
      id TEXT PRIMARY KEY,
      theme TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      embedding BLOB NOT NULL
    )
  ''');
  final insert = db.prepare(
    'INSERT INTO sample_entries(id, theme, title, body, embedding) VALUES (?, ?, ?, ?, ?)',
  );
  for (final row in sampleVaultRows) {
    insert.execute([
      row.id,
      row.theme,
      row.title,
      row.body,
      SampleVaultEmbedder.toBlob(SampleVaultEmbedder.embed(row.body)),
    ]);
  }
  insert.close();
  db.close();
  stdout.writeln('Wrote ${file.path} (${sampleVaultRows.length} entries)');
}
