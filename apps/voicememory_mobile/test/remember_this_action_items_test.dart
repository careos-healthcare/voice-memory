import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/action_items/action_item_filter.dart';
import 'package:voicememory_mobile/features/action_items/action_item_store.dart';
import 'package:voicememory_mobile/features/action_items/action_items_export.dart';
import 'package:voicememory_mobile/features/action_items/archive_action_item.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/export/selected_archive_export.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_influence_level.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/action_items_screen.dart';
import 'package:voicememory_mobile/screens/entry_detail_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/action_items/action_item_editor_sheet.dart';
import 'package:voicememory_mobile/widgets/action_items/remember_this_button.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _privateTitle = 'Call dentist about crown follow-up';
const _privateNote = 'Tuesday afternoon works best for me';

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

JournalEntry _entry({
  required String id,
  String transcript = 'A long enough transcript for action item tests here.',
  String? nextSmallAction,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12),
  transcript: transcript,
  durationSeconds: 20,
  reflection: Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: const ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Observation text.',
    repeatedSignal: 'signal',
    nextSmallAction: nextSmallAction,
  ),
);

Future<void> _pumpUntilActionItemsLoaded(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
  });
  await tester.pump();
}

void main() {
  late Directory tmp;
  late MobilePrefsStore prefs;
  late ActionItemStore store;
  late JournalStore journal;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('remember_this_test');
    prefs = await MobilePrefsStore.open('${tmp.path}/prefs.json');
    store = ActionItemStore.forPrefs(prefs);
    journal = await JournalStore.open('${tmp.path}/entries.json');
    await AppServices.resetForTest(
      journalPath: '${tmp.path}/entries_app.json',
      prefsPath: '${tmp.path}/prefs.json',
      skipRevenueCat: true,
    );
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
  });

  tearDown(() async {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('Remember this button', () {
    testWidgets('renders on entry detail', (tester) async {
      late Directory dir;
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('vm_remember_detail_');
        await AppServices.resetForTest(
          journalPath: '${dir.path}/entries.json',
          prefsPath: '${dir.path}/prefs.json',
          skipRevenueCat: true,
        );
        await AppServices.instance.journalStore.save(_entry(id: 'e1'));
      });
      addTearDown(() => dir.deleteSync(recursive: true));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const EntryDetailScreen(entryId: 'e1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('remember_this_button')), findsOneWidget);
      expect(find.text(ActionItemsCopy.rememberThis), findsOneWidget);
    });

    testWidgets('tapping Remember this opens editor', (tester) async {
      final entry = _entry(id: 'e1');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ActionItemEditorSheet(
              store: store,
              entry: entry,
              prefillTitle: 'Safe short title',
              source: 'test',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('action_item_title_field')), findsOneWidget);
      expect(find.byKey(const Key('action_item_save_button')), findsOneWidget);
      expect(find.text('Safe short title'), findsOneWidget);
    });

    test('remember this tap is tracked in analytics', () async {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.rememberThisTapped,
        source: 'entry_detail',
      );
      expect(
        _events.map((e) => e.name),
        contains(ActivationFunnelAnalytics.rememberThisTapped),
      );
    });
  });

  group('Action item lifecycle', () {
    test('saving creates action item', () async {
      final item = await store.create(
        sourceEntryId: 'e1',
        title: _privateTitle,
        note: _privateNote,
      );
      expect(item, isNotNull);
      expect(item!.title, _privateTitle);
      expect(item.status, ActionItemStatus.open);
    });

    test('action item persists after store reload', () async {
      await store.create(
        sourceEntryId: 'e1',
        title: _privateTitle,
        note: _privateNote,
      );
      final reloaded = ActionItemStore.forPrefs(prefs);
      final items = await reloaded.loadAll();
      expect(items, hasLength(1));
      expect(items.single.title, _privateTitle);
    });

    test('source entry remains unchanged', () async {
      final entry = _entry(id: 'e1', nextSmallAction: 'Auto suggested step');
      await journal.save(entry);
      await store.create(sourceEntryId: entry.id, title: _privateTitle);
      final reloaded = await journal.getById(entry.id);
      expect(reloaded!.reflection.nextSmallAction, 'Auto suggested step');
      expect(reloaded.transcript, entry.transcript);
    });

    test('action item references source entry safely', () async {
      final item = await store.create(
        sourceEntryId: 'entry_abc',
        title: _privateTitle,
      );
      expect(item!.sourceEntryId, 'entry_abc');
    });

    test(
      'generated interpretation does not create action item automatically',
      () async {
        final entry = _entry(
          id: 'e1',
          nextSmallAction: 'Suggested follow-up from reflection',
        );
        await journal.save(entry);
        final items = await store.loadAll();
        expect(items, isEmpty);
      },
    );

    test('summary cannot auto-create action item', () async {
      final entry = _entry(id: 'e1');
      await journal.save(entry);
      expect(entry.reflectionSummary, isNotEmpty);
      final items = await store.loadAll();
      expect(items, isEmpty);
    });
  });

  group('Action items screen', () {
    testWidgets('renders empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ActionItemsScreen(store: store),
        ),
      );
      await tester.pump();
      await _pumpUntilActionItemsLoaded(tester);

      expect(find.textContaining(ActionItemsCopy.emptyTitle), findsOneWidget);
      expect(find.textContaining(ActionItemsCopy.emptyHelper), findsOneWidget);
    });

    test('mark done works', () async {
      final item = await store.create(
        sourceEntryId: 'e1',
        title: _privateTitle,
      );
      final done = await store.markDone(item!.id);
      expect(done!.isDone, isTrue);
    });

    test('dismiss works without deleting source entry', () async {
      final entry = _entry(id: 'e1');
      await journal.save(entry);
      final item = await store.create(
        sourceEntryId: entry.id,
        title: _privateTitle,
      );
      final dismissed = await store.dismiss(item!.id);
      expect(await journal.getById(entry.id), isNotNull);
      expect(dismissed!.isDismissed, isTrue);
    });

    test('edit updates title/note locally', () async {
      final item = await store.create(
        sourceEntryId: 'e1',
        title: 'Old title',
        note: 'Old note',
      );
      final updated = await store.update(
        id: item!.id,
        title: _privateTitle,
        note: _privateNote,
      );
      expect(updated!.title, _privateTitle);
      expect(updated.note, _privateNote);
    });
  });

  group('Privacy', () {
    test('action item text is not logged in analytics', () async {
      await store.create(
        sourceEntryId: 'e1',
        title: _privateTitle,
        note: _privateNote,
      );
      await store.markDone((await store.loadAll()).single.id);
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.rememberThisTapped,
        source: _privateTitle,
        status: _privateTitle,
        actionItemCountBucket: _privateTitle,
      );

      final payloads = _events
          .map((e) => '${e.name} ${e.properties}')
          .join('\n');
      expect(payloads.contains(_privateTitle), isFalse);
      expect(payloads.contains(_privateNote), isFalse);
      for (final event in _events) {
        expect(
          event.properties.keys.toSet().difference(
            ActivationFunnelAnalytics.allowedPropertyKeys,
          ),
          isEmpty,
        );
      }
    });
  });

  group('Search and export', () {
    test('search/filter by action item works', () {
      final items = [
        ArchiveActionItem(
          id: 'a1',
          sourceEntryId: 'e1',
          title: 'Follow up on budget',
          note: '',
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
          status: ActionItemStatus.open,
        ),
        ArchiveActionItem(
          id: 'a2',
          sourceEntryId: 'e2',
          title: 'Other task',
          note: '',
          createdAt: DateTime(2026, 6, 11),
          updatedAt: DateTime(2026, 6, 11),
          status: ActionItemStatus.open,
        ),
      ];
      final filtered = ActionItemFilter.search(items, 'budget');
      expect(filtered, hasLength(1));
      expect(filtered.single.sourceEntryId, 'e1');
    });

    test(
      'archive entry with action item appears under Action items filter',
      () {
        const engine = ArchiveEntrySearchEngine();
        final entries = [
          _entry(id: 'e1'),
          _entry(id: 'e2', transcript: 'Another long enough transcript here.'),
        ];
        final results = engine.search(
          entries: entries,
          query: const ArchiveEntrySearchQuery(actionItemsOnly: true),
          entryIdsWithActionItems: {'e1'},
        );
        expect(results, hasLength(1));
        expect(results.single.entry.id, 'e1');
      },
    );

    test('export action items creates selected markdown', () {
      final items = [
        ArchiveActionItem(
          id: 'a1',
          sourceEntryId: 'e1',
          title: _privateTitle,
          note: _privateNote,
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
          status: ActionItemStatus.open,
        ),
        ArchiveActionItem(
          id: 'a2',
          sourceEntryId: 'e2',
          title: 'Dismissed item',
          note: '',
          createdAt: DateTime(2026, 6, 11),
          updatedAt: DateTime(2026, 6, 11),
          status: ActionItemStatus.dismissed,
        ),
      ];
      final markdown = const ActionItemsExport().buildMarkdown(
        items: ActionItemFilter.exportableItems(items),
      );
      expect(markdown.contains(_privateTitle), isTrue);
      expect(markdown.contains(_privateNote), isTrue);
      expect(markdown.contains('Dismissed item'), isFalse);
      expect(
        ActionItemsExport.fileName(DateTime(2026, 6, 12)),
        'archiveme-action-items-2026-06-12.md',
      );
    });

    test('export does not include unselected action items', () {
      final items = [
        ArchiveActionItem(
          id: 'a1',
          sourceEntryId: 'e1',
          title: _privateTitle,
          note: '',
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
          status: ActionItemStatus.open,
        ),
        ArchiveActionItem(
          id: 'a2',
          sourceEntryId: 'e2',
          title: 'Unselected item',
          note: '',
          createdAt: DateTime(2026, 6, 11),
          updatedAt: DateTime(2026, 6, 11),
          status: ActionItemStatus.open,
        ),
      ];
      final markdown = const SelectedArchiveExport().buildMarkdown(
        selectedEntries: [_entry(id: 'e1')],
        actionItems: items,
      );
      expect(markdown.contains(ActionItemsCopy.exportMarkerOpen), isTrue);
      expect(markdown.contains('Unselected item'), isFalse);
    });
  });

  group('Memory safeguards', () {
    test(
      'action item status does not create memory authority by itself',
      () async {
        const engine = MemoryAuthorityFramingEngine();
        final records = [
          PressureCheckInRecord(
            entryId: 'e1',
            createdAt: DateTime(2026, 6, 12),
            optionId: 'could_not_stop',
          ),
        ];
        final before = engine.frame(
          records,
          now: DateTime(2026, 6, 12),
          cardType: MemoryCardType.threadReturn,
        );
        await store.create(sourceEntryId: 'e1', title: _privateTitle);
        final after = engine.frame(
          records,
          now: DateTime(2026, 6, 12),
          cardType: MemoryCardType.threadReturn,
        );
        expect(before.frame.influenceLevel, after.frame.influenceLevel);
        expect(
          after.frame.influenceLevel,
          isNot(MemoryInfluenceLevel.highAuthority),
        );
      },
    );
  });

  group('Optional due date', () {
    test('due date copy exists and does not auto-request permission', () {
      expect(ActionItemsCopy.addReminder, isNotEmpty);
      expect(ActionItemsCopy.chooseDate, isNotEmpty);
      expect(ActionItemsCopy.reminderSaved, isNotEmpty);
    });
  });

  group('Copy guardrails', () {
    test('no VoiceMemory in consumer copy', () {
      for (final line in ActionItemsCopy.all) {
        expect(line.contains('VoiceMemory'), isFalse);
      }
    });

    test('banned-word sweep', () {
      final corpus = [
        ...ActionItemsCopy.all,
        ActionItemsCopy.exportMarkerOpen,
        ActionItemsCopy.exportMarkerDone,
      ].join('\n').toLowerCase();
      for (final word in _bannedWords) {
        expect(
          RegExp('\\b${word.toLowerCase()}\\b').hasMatch(corpus),
          isFalse,
          reason: 'banned word: $word',
        );
      }
    });
  });
}
