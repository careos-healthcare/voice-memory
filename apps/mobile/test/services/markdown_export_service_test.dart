import 'dart:io';

import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/markdown_export_service.dart';
import 'package:archiveme_mobile/services/obsidian_markdown_template.dart';
import 'package:archiveme_mobile/services/obsidian_vault_diff.dart';
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
    PremiumAccess.apply(PremiumEntitlement.active);
    addTearDown(() => PremiumAccess.apply(PremiumEntitlement.free));
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

  test('a user template places the transcript, metadata, and patterns', () {
    const template = ObsidianMarkdownTemplate('''
# {{date}}
mood: {{mood}}
{{#patterns}}
## Patterns
{{patterns}}
{{/patterns}}

{{transcript}}
''');
    final note = MarkdownNote(
      id: 'e1',
      createdAt: DateTime.utc(2026, 3, 3),
      body: 'Said it out loud.',
      mood: 'steady',
      tags: const ['journal'],
      patterns: const ['morning'],
    );

    final markdown = template.render(ObsidianTemplateValues.fromNote(note));

    expect(markdown, contains('# 2026-03-03'));
    expect(markdown, contains('mood: steady'));
    expect(markdown, contains('## Patterns\n- morning'));
    expect(markdown, contains('Said it out loud.'));
  });

  test('a free account does not write the Obsidian vault', () async {
    PremiumAccess.apply(PremiumEntitlement.free);
    final directory = await Directory.systemTemp.createTemp('obsidian_free');
    addTearDown(() => directory.delete(recursive: true));
    final service = MarkdownExportService(
      pickDirectory: () async => directory.path,
    );
    expect(await service.chooseVault(), directory.path);
    expect(await service.sync([_entry('Stays on device.')]), 0);
    expect(directory.listSync(), isEmpty);
  });

  test('vault diff skips duplicates and keeps an edited note', () async {
    final directory = await Directory.systemTemp.createTemp('obsidian_diff');
    addTearDown(() => directory.delete(recursive: true));
    PremiumAccess.apply(PremiumEntitlement.active);
    addTearDown(() => PremiumAccess.apply(PremiumEntitlement.free));
    final service = MarkdownExportService(
      pickDirectory: () async => directory.path,
    );
    final entry = _entry('First wording.');
    expect(await service.chooseVault(), directory.path);
    expect(await service.sync([entry]), 1);

    expect(await service.sync([entry]), 0);

    final file = File('${directory.path}/2026-03-03-e1.md');
    await file.writeAsString('edited in the vault\n');
    final updated = _entry('Second wording.');
    expect(await service.sync([updated]), 0);
    expect(await file.readAsString(), 'edited in the vault\n');
    expect(
      ObsidianVaultDiff.resolve(
        localMarkdown: 'local',
        vaultMarkdown: 'vault',
        lastPushedHash: ObsidianVaultDiff.hashOf('local'),
      ),
      ObsidianVaultPush.keepVault,
    );
    final localTime = DateTime.utc(2026, 3, 3, 9);
    expect(
      ObsidianVaultDiff.resolve(
        localMarkdown: 'newer local',
        vaultMarkdown: 'older vault',
        lastPushedHash: null,
        localUpdatedAt: localTime,
        vaultModifiedAt: localTime.subtract(const Duration(hours: 1)),
      ),
      ObsidianVaultPush.write,
    );
    expect(
      ObsidianVaultDiff.resolve(
        localMarkdown: 'local',
        vaultMarkdown: 'vault edited later',
        lastPushedHash: null,
        localUpdatedAt: localTime,
        vaultModifiedAt: localTime.add(const Duration(hours: 2)),
      ),
      ObsidianVaultPush.keepVault,
    );
  });

  test('a template includes extracted person and place tags', () {
    final note = MarkdownNote.fromEntry(
      _entry('Met Ada.').copyWith(
        reflection: const Reflection(
          mood: 'calm',
          emotionalIntensity: 1,
          recurringThemes: ['person:Ada', 'place:London', 'morning'],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      ),
    );
    final markdown = const ObsidianMarkdownTemplate(
      ObsidianMarkdownTemplate.defaultSource,
    ).render(ObsidianTemplateValues.fromNote(note));
    expect(markdown, contains('person:Ada'));
    expect(markdown, contains('place:London'));
    expect(markdown, isNot(contains('extracted_tags:\n  - morning')));
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
