import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/markdown_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frontmatter is dataview readable', () {
    final note = MarkdownNote(
      id: 'e1',
      createdAt: DateTime.utc(2026, 3, 3, 9),
      body: 'The morning felt lighter.',
      mood: 'reflective',
      tags: const ['journal', 'morning'],
      ambient: const MarkdownAmbient(
        locality: 'London',
        weather: '18°C',
        steps: 4200,
        calendar: 'Design review',
      ),
    );

    final markdown = renderMarkdownNote(note);

    expect(markdown, startsWith('---\n'));
    expect(markdown, contains('\ndate: 2026-03-03\n'));
    expect(markdown, contains('tags:\n  - journal\n  - morning\n'));
    expect(markdown, contains('\nmood: reflective\n'));
    expect(markdown, contains('\nambient_locality: London\n'));
    expect(markdown, contains('\nambient_weather: 18°C\n'));
    expect(markdown, contains('\nambient_steps: 4200\n'));
    expect(markdown, contains('\nambient_calendar: Design review\n'));
    expect(markdown, contains('\n---\n\nThe morning felt lighter.\n'));
  });

  test('choosing a folder keeps rewriting notes into that vault', () async {
    final directory = await Directory.systemTemp.createTemp('obsidian_vault');
    addTearDown(() => directory.delete(recursive: true));
    final service = MarkdownExportService(
      pickDirectory: () async => directory.path,
    );
    final entry = _entry('The morning felt lighter.');

    expect(await service.chooseVault(), directory.path);
    expect(await service.sync([entry]), 1);
    final file = File('${directory.path}/2026-03-03-e1.md');
    expect(await file.readAsString(), contains('mood: reflective'));

    final updated = _entry('The morning felt lighter still.');
    final written = await service.syncStream([updated]).toList();
    expect(written.single.path, file.path);
    expect(await file.readAsString(), contains('lighter still'));
  });
}

JournalEntry _entry(String transcript) {
  final created = DateTime.utc(2026, 3, 3, 9);
  return JournalEntry.stored(
    id: 'e1',
    createdAt: created,
    transcript: transcript,
    durationSeconds: 0,
    reflection: const Reflection(
      mood: 'reflective',
      emotionalIntensity: 1,
      recurringThemes: ['morning'],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    sync: JournalSyncMetadata(createdAt: created, entryId: 'e1'),
    display: const JournalDisplayMetadata(),
    proof: const JournalProofData(),
  );
}
