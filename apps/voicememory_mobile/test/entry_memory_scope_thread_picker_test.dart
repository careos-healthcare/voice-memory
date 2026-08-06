import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_query.dart';
import 'package:voicememory_mobile/features/memory/archive_thread_store.dart';
import 'package:voicememory_mobile/features/memory/entry_memory_mode.dart';
import 'package:voicememory_mobile/features/memory/entry_thread_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_influence_level.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/memory/treat_as_new.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/memory/entry_memory_scope_picker.dart';
import 'package:voicememory_mobile/widgets/memory/entry_options_section.dart';
import 'package:voicememory_mobile/widgets/memory/entry_thread_picker.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(
        file: File(
          '${Directory.systemTemp.createTempSync('vm_entry_scope_').path}/prefs.json',
        ),
      ) {
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    if (!file.existsSync()) {
      file.writeAsStringSync('{}');
    }
  }

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>> updateMap(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>? current) transform,
  ) async {
    final result = transform(maps[key]);
    maps[key] = result;
    return result;
  }

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

JournalEntry _entry({String id = 'e1', String? archiveThreadId}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 11, 12),
    transcript: 'Enough transcript text for a saved reflection entry.',
    durationSeconds: 20,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work showed up again.',
      repeatedSignal: 'signal',
    ),
    archiveThreadId: archiveThreadId,
  );
}

PressureCheckInRecord _rec({
  String id = 'e1',
  List<String> contexts = const [],
  String? archiveThreadId,
  bool treatAsNew = false,
  bool keepSeparate = false,
  bool connectionApproved = false,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime(2026, 6, 11, 12),
  optionId: 'work_pressure',
  contextIds: contexts,
  archiveThreadId: archiveThreadId,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
  connectionApproved: connectionApproved,
  fear: 'I keep circling the same work decision',
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
];

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    MemoryScopePolicy.resetForTest();
    EntryMemoryModeSession.resetSessionForTest();
    EntryThreadScopeSession.resetSessionForTest();
    TreatAsNew.resetSessionForTest();
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('Entry memory mode picker', () {
    testWidgets('renders three options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: EntryMemoryScopePicker()),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('entry_memory_scope_picker')),
        findsOneWidget,
      );
      expect(find.text('Use archive context'), findsOneWidget);
      expect(find.text('Treat as new'), findsOneWidget);
      expect(find.text('Keep separate'), findsOneWidget);
    });

    testWidgets('global memory off shows static notice', (tester) async {
      MemoryScopePolicy.scope = MemoryScope.off;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: EntryMemoryScopePicker()),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('entry_memory_scope_off')), findsOneWidget);
      expect(find.text('Memory is off'), findsOneWidget);
      expect(
        find.byKey(const Key('entry_memory_mode_use_archive_context')),
        findsNothing,
      );
    });

    test('default mode is use archive context', () {
      expect(
        EntryMemoryModeSession.selectedMode,
        EntryMemoryMode.useArchiveContext,
      );
    });
  });

  group('Save integration', () {
    late Directory tempDir;
    test('Treat as new sets fresh metadata', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_entry_mode_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      EntryMemoryModeSession.select(EntryMemoryMode.treatAsNew);
      final store = AppServices.instance.journalStore;
      await store.save(_entry());
      final saved = (await store.loadAll()).single;
      expect(saved.treatAsNew, isTrue);
      expect(saved.keepSeparate, isFalse);
    });

    test('Keep separate sets durable metadata and suppresses claims', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_keep_sep_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      EntryMemoryModeSession.select(EntryMemoryMode.keepSeparate);
      final store = AppServices.instance.journalStore;
      await store.save(_entry());
      final saved = (await store.loadAll()).single;
      expect(saved.keepSeparate, isTrue);
      expect(
        MemoryScopePolicy.connectionEligible([
          PressureCheckInRecord(
            entryId: saved.id,
            createdAt: saved.createdAt,
            optionId: PressureCheckInRecord.contextOnlyOptionId,
            keepSeparate: true,
          ),
        ]),
        isEmpty,
      );
    });

    test('keep separate entries still appear in search', () {
      const engine = ArchiveEntrySearchEngine();
      final entry = JournalEntry(
        id: 'sep',
        createdAt: DateTime(2026, 6, 11),
        transcript: 'Enough transcript text for a saved reflection entry.',
        durationSeconds: 20,
        reflection: _entry().reflection,
        keepSeparate: true,
      );
      final results = engine.search(
        entries: [entry],
        query: const ArchiveEntrySearchQuery(),
      );
      expect(results, isNotEmpty);
    });
  });

  group('Thread picker', () {
    testWidgets('renders thread scope options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: EntryThreadPicker(threads: [])),
        ),
      );
      await tester.pump();
      expect(find.text('No thread'), findsOneWidget);
      expect(find.text('Existing thread'), findsOneWidget);
      expect(find.text('New thread'), findsOneWidget);
    });

    test('new thread creates safe id', () async {
      final prefs = _MemoryPrefs();
      final store = ArchiveThreadStore.forPrefs(prefs);
      final thread = await store.create('Project Alpha');
      expect(thread, isNotNull);
      expect(thread!.id.startsWith('thr_'), isTrue);
      expect(thread.name, 'Project Alpha');
    });

    test('threadOnly uses explicit archive thread linkage', () {
      MemoryScopePolicy.scope = MemoryScope.threadOnly;
      final records = [
        _rec(id: 'a', archiveThreadId: 'thr_1'),
        _rec(id: 'b', archiveThreadId: 'thr_1'),
        _rec(id: 'c', contexts: const ['work'], archiveThreadId: 'thr_other'),
      ];
      final eligible = MemoryScopePolicy.connectionEligible(records);
      expect(eligible.map((r) => r.entryId), containsAll(['a', 'b']));
      expect(eligible.map((r) => r.entryId), isNot(contains('c')));
    });

    test('thread names are not logged in analytics', () async {
      final prefs = _MemoryPrefs();
      final store = ArchiveThreadStore.forPrefs(prefs);
      await store.create('Private Thread Name');
      for (final e in captured) {
        expect(
          '${e.event} ${e.properties}'.toLowerCase(),
          isNot(contains('private thread name')),
        );
      }
    });
  });

  group('Authority framing', () {
    test('thread assignment alone does not create high authority', () {
      const engine = MemoryAuthorityFramingEngine();
      MemoryScopePolicy.scope = MemoryScope.threadOnly;
      final records = [
        _rec(id: 'a', archiveThreadId: 'thr_1'),
        _rec(id: 'b', archiveThreadId: 'thr_1'),
      ];
      final framing = engine.frame(
        records,
        cardType: MemoryCardType.threadReturn,
      );
      expect(framing.frame.influenceLevel.id, isNot('high_authority'));
    });
  });

  group('Zero-entry UX', () {
    testWidgets('entry options collapsed under Entry options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: EntryOptionsSection(entryCount: 0)),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('entry_options_expansion')), findsOneWidget);
      expect(find.text('Advanced save options'), findsOneWidget);
    });
  });

  group('Copy guardrails', () {
    test('no VoiceMemory or banned words', () {
      final copy = [
        ...EntryMemoryModeCopy.all,
        ...EntryThreadScopeCopy.all,
      ].join(' ').toLowerCase();
      expect(copy, isNot(contains('voicememory')));
      for (final banned in _bannedWords) {
        expect(copy, isNot(contains(banned)), reason: banned);
      }
    });
  });
}
