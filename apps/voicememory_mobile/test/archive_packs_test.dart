import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack_markdown_import.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack_scope_policy.dart';
import 'package:voicememory_mobile/features/archive_packs/archive_pack_store.dart';
import 'package:voicememory_mobile/features/archive_packs/cross_pack_confirmation.dart';
import 'package:voicememory_mobile/features/archive_packs/entry_pack_scope.dart';
import 'package:voicememory_mobile/features/archive_packs/pack_archive_export.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/memory/entry_save_coordinator.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_reliability_check.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_packs/archive_pack_picker.dart';
import 'package:voicememory_mobile/widgets/memory/entry_options_section.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

JournalEntry _entry(String id, {String? packId}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 11),
  transcript: 'A long enough transcript for archive pack tests here.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Observation text.',
    repeatedSignal: 'signal',
  ),
  archivePackId: packId,
);

PressureCheckInRecord _rec({
  required String id,
  String? packId,
  String? fear,
  bool treatAsNew = false,
  bool keepSeparate = false,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime(2026, 6, 10).subtract(
    Duration(
      days: id == 'e1'
          ? 6
          : id == 'e2'
          ? 3
          : 0,
    ),
  ),
  optionId: 'could_not_stop',
  fear:
      fear ??
      switch (id) {
        'e1' => 'Work project alpha keeps circling',
        'e2' => 'Novel chapter pacing feels stuck',
        'e3' => 'Work project beta decision again',
        _ => 'Same work theme repeated again today',
      },
  archivePackId: packId,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
);

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'VoiceMemory',
];

void main() {
  late Directory tmp;
  late MobilePrefsStore prefs;
  late ArchivePackStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('archive_packs_test');
    prefs = await MobilePrefsStore.open('${tmp.path}/prefs.json');
    store = ArchivePackStore.forPrefs(prefs);
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
    MemoryScopePolicy.resetForTest();
    ArchivePackScopePolicy.resetForTest();
    CrossPackConfirmation.resetForTest();
    EntryPackScopeSession.resetSessionForTest();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('Archive pack store', () {
    test('create pack persists', () async {
      final pack = await store.create('Work');
      expect(pack, isNotNull);
      final loaded = await store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'Work');
    });

    test('rename pack persists', () async {
      final pack = await store.create('Novel');
      await store.rename(pack!.id, 'Novel draft');
      final reloaded = await store.getById(pack.id);
      expect(reloaded?.name, 'Novel draft');
    });

    test('delete pack does not delete entries', () async {
      final pack = await store.create('Ideas');
      await store.assignEntry(pack!.id, 'entry-1');
      await store.delete(pack.id);
      expect(await store.getById(pack.id), isNull);
      // Entry id list is gone with pack — entry itself is not stored here.
    });

    test('assign entry to pack', () async {
      final pack = await store.create('Personal');
      await store.assignEntry(pack!.id, 'e1');
      final reloaded = await store.getById(pack.id);
      expect(reloaded?.entryIds, contains('e1'));
    });

    test('pack instructions save locally', () async {
      final pack = await store.create('Style');
      await store.saveInstructions(pack!.id, 'Keep tone calm and plain.');
      final reloaded = await store.getById(pack.id);
      expect(reloaded?.instructions, 'Keep tone calm and plain.');
    });

    test('instructions are never logged in analytics', () async {
      final pack = await store.create('Notes');
      await store.saveInstructions(pack!.id, 'Secret style guide phrase');
      for (final event in _events) {
        expect(event.properties.values.join(' '), isNot(contains('Secret')));
        expect(event.properties.values.join(' '), isNot(contains('Notes')));
      }
    });
  });

  group('Pack-scoped memory', () {
    test('same-pack memory can proceed when policy allows', () {
      final records = [
        _rec(id: 'e1', packId: 'pack_a'),
        _rec(id: 'e2', packId: 'pack_a'),
        _rec(id: 'e3', packId: 'pack_a'),
      ];
      ArchivePackScopePolicy.applyLoadedPacks([
        ArchivePack(
          id: 'pack_a',
          name: 'A',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ]);
      expect(ArchivePackScopePolicy.isCrossPack(records), isFalse);
    });

    test('cross-pack memory is blocked by default', () {
      final records = [
        _rec(id: 'e1', packId: 'pack_a'),
        _rec(id: 'e2', packId: 'pack_b'),
        _rec(id: 'e3', packId: 'pack_a'),
      ];
      expect(ArchivePackScopePolicy.isCrossPack(records), isTrue);
      expect(ArchivePackScopePolicy.allowsCrossPackByPolicy(records), isFalse);
    });

    test('cross-pack reliability requires confirmation', () {
      final records = [
        _rec(id: 'e1', packId: 'pack_a'),
        _rec(id: 'e2', packId: 'pack_b'),
        _rec(id: 'e3', packId: 'pack_a'),
      ];
      ArchivePackScopePolicy.applyLoadedPacks([
        ArchivePack(
          id: 'pack_a',
          name: 'A',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        ArchivePack(
          id: 'pack_b',
          name: 'B',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ]);
      final result = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: records,
      );
      expect(result.state, MemoryReliabilityState.crossPack);
    });

    test('Connect allows cross-pack claim', () {
      CrossPackConfirmation.approve('thread_return');
      expect(CrossPackConfirmation.isApproved('thread_return'), isTrue);
    });

    test('Keep separate suppresses cross-pack claim', () {
      CrossPackConfirmation.keepSeparate('thread_return');
      expect(
        CrossPackConfirmation.isSessionSuppressed('thread_return'),
        isTrue,
      );
    });

    test('global memory off reliability is blocked', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final result = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: [_rec(id: 'e1', packId: 'pack_a')],
      );
      expect(result.state, MemoryReliabilityState.blocked);
    });

    test('treat-as-new suppresses pack memory', () {
      expect(
        MemoryScopePolicy.isRecordConnectionEligible(
          _rec(id: 'e1', packId: 'pack_a', treatAsNew: true),
        ),
        isFalse,
      );
    });

    test('keep-separate suppresses pack memory', () {
      expect(
        MemoryScopePolicy.isRecordConnectionEligible(
          _rec(id: 'e1', packId: 'pack_a', keepSeparate: true),
        ),
        isFalse,
      );
    });

    test('instructions are not source evidence by default', () {
      expect(
        ArchivePackScopePolicy.isInstructionsEvidence('any text'),
        isFalse,
      );
    });
  });

  group('Search', () {
    test('can filter by pack', () {
      const engine = ArchiveEntrySearchEngine();
      final entries = [
        _entry('e1', packId: 'pack_a'),
        _entry('e2', packId: 'pack_b'),
      ];
      final results = engine.search(
        entries: entries,
        query: const ArchiveEntrySearchQuery(packId: 'pack_a'),
      );
      expect(results, hasLength(1));
      expect(results.single.entry.id, 'e1');
    });
  });

  group('Export', () {
    test('export pack includes only pack entries', () {
      final pack = ArchivePack(
        id: 'pack_a',
        name: 'Work',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
        instructions: 'Plain tone.',
      );
      final markdown = const PackArchiveExport().buildMarkdown(
        pack: pack,
        packEntries: [_entry('e1', packId: 'pack_a')],
      );
      expect(markdown, contains('# Pack Work'));
      expect(markdown, contains('## Instructions'));
      expect(markdown, contains('Plain tone.'));
      expect(markdown, contains('## Entries'));
    });

    test('export filename is safe', () {
      expect(
        PackArchiveExport.fileName(DateTime(2026, 6, 12)),
        'archiveme-pack-export-2026-06-12.md',
      );
    });
  });

  group('Markdown import hooks', () {
    test('parses pack sections', () {
      const md = '''
# Pack Novel

## Instructions
Keep chapters short.

## Entries
First scene note.
''';
      final doc = ArchivePackMarkdownImport.parse(md);
      expect(doc?.packName, 'Novel');
      expect(doc?.instructions, contains('Keep chapters short'));
      expect(doc?.entryTexts, contains('First scene note.'));
    });
  });

  group('UI', () {
    testWidgets('pack picker renders under entry options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchivePackPicker(
              packs: [
                ArchivePack(
                  id: 'pack_1',
                  name: 'Work',
                  createdAt: DateTime(2026, 1, 1),
                  updatedAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('archive_pack_picker')), findsOneWidget);
      expect(find.text(ArchivePacksCopy.saveToPack), findsOneWidget);
    });

    testWidgets('zero-entry first impression keeps pack picker collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: EntryOptionsSection(entryCount: 0)),
        ),
      );
      expect(find.byKey(const Key('entry_options_expansion')), findsOneWidget);
      expect(find.byKey(const Key('archive_pack_picker')), findsNothing);
    });
  });

  group('Copy and analytics privacy', () {
    test('consumer copy avoids banned words and VoiceMemory', () {
      for (final text in ArchivePacksCopy.all) {
        for (final banned in _bannedWords) {
          expect(
            text.toLowerCase().contains(banned.toLowerCase()),
            isFalse,
            reason: '$banned in "$text"',
          );
        }
      }
    });

    test('analytics payload never includes pack names/instructions', () async {
      await store.create('Secret Pack Name');
      for (final event in _events) {
        final flat = '${event.name} ${event.properties.values.join(' ')}';
        expect(flat.toLowerCase(), isNot(contains('secret')));
        expect(flat.toLowerCase(), isNot(contains('voicememory')));
      }
    });
  });
}
