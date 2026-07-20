import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/data/models/curiosity_reaction_record.dart';
import 'package:voicememory_mobile/features/curiosity_loop/data/repositories/curiosity_reaction_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_data_exporter.dart';
import 'package:voicememory_mobile/features/curiosity_loop/yesterdays_snapshot_reaction.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/journal_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

const _reflection = Reflection(
  mood: 'thoughtful',
  emotionalIntensity: 2,
  recurringThemes: ['work'],
  exactLanguagePattern: '',
  concreteObservation: 'Work pressure showed up again today.',
  repeatedSignal: 'said yes again',
);

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: 'I said yes again even though I had no capacity.',
    durationSeconds: 30,
    localAudioPath: '/tmp/$id.m4a',
    reflection: _reflection,
  );
}

CuriosityHook _hook() => CuriosityHook(
      id: 'hook_1',
      entryId: 'entry_1',
      createdAt: DateTime.utc(2026, 6, 11, 12),
      primaryAnchor: 'said yes again',
      hookType: CuriosityHookType.blocker,
      dynamicPrompt:
          'Before "said yes again" showed up again, what got in the way?',
    );

Future<
    ({
      JournalService journal,
      LocalCuriosityHookRepository hooks,
      InMemoryCuriosityReactionRepository reactions,
      Directory dir,
    })> _openFixture() async {
  final dir = await Directory.systemTemp.createTemp('curiosity_export_test_');
  final journalStore = await JournalStore.open(
    '${dir.path}/journal.json',
    encryptAtRest: false,
  );
  final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
  await LocalCuriosityHookRepository.resetForTest(prefs);

  return (
    journal: JournalService(journalStore),
    hooks: LocalCuriosityHookRepository.forPrefs(prefs),
    reactions: InMemoryCuriosityReactionRepository(),
    dir: dir,
  );
}

void main() {
  group('CuriosityDataExporter', () {
    test('exportAsMarkdown includes summary table and entry anchors', () async {
      final fixture = await _openFixture();
      addTearDown(() => fixture.dir.deleteSync(recursive: true));

      final windowStart = DateTime.utc(2026, 6, 11);
      final windowEnd = DateTime.utc(2026, 6, 18, 23, 59, 59);

      final journalStore = await JournalStore.open(
        '${fixture.dir.path}/journal.json',
        encryptAtRest: false,
      );
      await journalStore.save(_entry(id: 'entry_1', createdAt: DateTime.utc(2026, 6, 12, 9)));
      await fixture.hooks.saveHook(_hook());
      await fixture.reactions.logReaction(
        CuriosityReactionRecord(
          id: 'reaction_1',
          hookId: 'hook_1',
          timestamp: DateTime.utc(2026, 6, 13, 8),
          reactionType: YesterdaysSnapshotReaction.stuck,
          primaryAnchor: 'said yes again',
          hookType: CuriosityHookType.blocker,
        ),
      );

      final exporter = CuriosityDataExporter(
        journalService: JournalService(journalStore),
        reactionRepository: fixture.reactions,
        hookRepository: fixture.hooks,
      );

      final markdown = await exporter.exportAsMarkdown(
        start: windowStart,
        end: windowEnd,
      );

      expect(markdown, contains('# ArchiveMe — Curiosity Loop Export'));
      expect(markdown, contains('2026-06-11 → 2026-06-18'));
      expect(markdown, contains('## Reaction summary'));
      expect(markdown, contains('| Reaction | Count | Share |'));
      expect(markdown, contains('🟡 Stuck'));
      expect(markdown, contains('## Journal moments'));
      expect(markdown, contains('**Anchor:** said yes again'));
      expect(markdown, contains('**Emotional tone:** thoughtful'));
      expect(markdown, contains('Work pressure showed up again today.'));
    });

    test('exportAsJson serializes backup schema with summary and entries', () async {
      final fixture = await _openFixture();
      addTearDown(() => fixture.dir.deleteSync(recursive: true));

      final journalStore = await JournalStore.open(
        '${fixture.dir.path}/journal.json',
        encryptAtRest: false,
      );
      await journalStore.save(_entry(id: 'entry_1', createdAt: DateTime.utc(2026, 6, 12, 9)));
      await fixture.hooks.saveHook(_hook());
      await fixture.reactions.logReaction(
        CuriosityReactionRecord(
          id: 'reaction_1',
          hookId: 'hook_1',
          timestamp: DateTime.utc(2026, 6, 13, 8),
          reactionType: YesterdaysSnapshotReaction.progressed,
          primaryAnchor: 'finished the draft',
          hookType: CuriosityHookType.momentum,
        ),
      );

      final exporter = CuriosityDataExporter(
        journalService: JournalService(journalStore),
        reactionRepository: fixture.reactions,
        hookRepository: fixture.hooks,
      );

      final json = await exporter.exportAsJson(
        start: DateTime.utc(2026, 6, 11),
        end: DateTime.utc(2026, 6, 18, 23, 59, 59),
      );

      expect(json['schemaVersion'], CuriosityDataExporter.schemaVersion);
      expect(json['window'], isA<Map>());
      expect(json['summary'], isA<Map>());
      expect((json['summary'] as Map)['totalReactions'], 1);
      expect((json['summary'] as Map)['totalEntries'], 1);
      expect(json['entries'], isA<List>());
      expect((json['entries'] as List), hasLength(1));

      final entry = (json['entries'] as List).single as Map<String, dynamic>;
      expect(entry['entryId'], 'entry_1');
      expect(entry['primaryAnchor'], 'said yes again');
      expect(entry['emotionalTone'], 'thoughtful');
      expect(entry['reaction'], isA<Map>());
      expect((entry['reaction'] as Map)['type'], 'progressed');
      expect((entry['reaction'] as Map)['emoji'], '🟢');

      expect(json['reactions'], isA<List>());
      expect((json['reactions'] as List), hasLength(1));
      expect(json['hooks'], isA<List>());
      expect((json['hooks'] as List), hasLength(1));
    });

    test('handles empty windows without throwing', () async {
      final fixture = await _openFixture();
      addTearDown(() => fixture.dir.deleteSync(recursive: true));

      final journalStore = await JournalStore.open(
        '${fixture.dir.path}/journal.json',
        encryptAtRest: false,
      );

      final exporter = CuriosityDataExporter(
        journalService: JournalService(journalStore),
        reactionRepository: fixture.reactions,
        hookRepository: fixture.hooks,
      );

      final markdown = await exporter.exportAsMarkdown(
        start: DateTime.utc(2026, 6, 11),
        end: DateTime.utc(2026, 6, 18),
      );
      final json = await exporter.exportAsJson(
        start: DateTime.utc(2026, 6, 11),
        end: DateTime.utc(2026, 6, 18),
      );

      expect(markdown, contains('_No return-day reactions in this window_'));
      expect(markdown, contains('_No journal entries were saved during this window._'));
      expect((json['summary'] as Map)['totalReactions'], 0);
      expect((json['summary'] as Map)['totalEntries'], 0);
      expect(json['entries'], isEmpty);
      expect(json['reactions'], isEmpty);
    });
  });
}
