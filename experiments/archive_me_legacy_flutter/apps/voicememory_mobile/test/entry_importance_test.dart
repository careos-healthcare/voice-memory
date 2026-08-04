import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/entry_importance/entry_importance_analytics.dart';
import 'package:voicememory_mobile/features/entry_importance/entry_importance_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_history/archive_history_sheet.dart';
import 'package:voicememory_mobile/widgets/record/post_save_recorded_summary_card.dart';

const _realMoment =
    'I felt pressure to say yes again before checking my capacity today.';

JournalEntry _textEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 24,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    EntryImportanceAnalytics.resetForTest();
    await EntryImportanceStore.resetForTest();
  });

  group('EntryImportanceStore', () {
    test('marks entry by id', () async {
      await EntryImportanceStore.instance().mark('e1');
      expect(EntryImportanceStore.isImportant('e1'), isTrue);
    });

    test('unmarks important entry', () async {
      await EntryImportanceStore.instance().mark('e2');
      await EntryImportanceStore.instance().unmark('e2');
      expect(EntryImportanceStore.isImportant('e2'), isFalse);
    });

    test('archive reset clears markers', () async {
      await EntryImportanceStore.instance().mark('e1');
      await EntryImportanceStore.clearAll();
      expect(EntryImportanceStore.isImportant('e1'), isFalse);

      final source = File(
        'lib/security/local_privacy_data_controls.dart',
      ).readAsStringSync();
      expect(source, contains('EntryImportanceStore.clearAll'));
    });
  });

  group('EntryImportanceEngine', () {
    test('prioritizes important rows without changing proof status', () async {
      await EntryImportanceStore.instance().mark('older');
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(
            id: 'newer',
            transcript: _realMoment,
            createdAt: DateTime(2026, 6, 14, 12),
          ),
          _textEntry(
            id: 'older',
            transcript: 'A quiet lunch with a friend today.',
            createdAt: DateTime(2026, 6, 10, 12),
          ),
        ],
      );

      expect(content.items.first.entryId, 'older');
      expect(content.items.first.isImportant, isTrue);
      expect(
        content.items.every((item) => item.status.toString().isNotEmpty),
        isTrue,
      );
    });

    test('marker does not make generic weak entry usable for proof', () async {
      final generic = _textEntry(
        id: 'generic',
        transcript: 'hello checking mic test',
      );
      await EntryImportanceStore.instance().mark('generic');

      final verdict = ArchiveEvidenceQuality.assess(generic);
      expect(verdict.allowsInsights, isFalse);

      final content = ArchiveHistoryEngine.build(entries: [generic]);
      expect(content.items.single.isImportant, isTrue);
      expect(
        content.items.single.status.toString(),
        contains('ignoredForPatterns'),
      );
    });
  });

  group('EntryImportanceAnalytics', () {
    test('emits metadata only without transcript text', () async {
      final events = <String, Map<String, Object>>{};
      EntryImportanceAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };

      await EntryImportanceStore.instance().mark('secret-entry');
      EntryImportanceAnalytics.marked(
        source: 'post_save_summary',
        entryCount: 2,
      );

      expect(events.keys, contains(EntryImportanceAnalytics.markedEvent));
      final props = events[EntryImportanceAnalytics.markedEvent]!;
      expect(props.keys, containsAll(['source', 'entry_count']));
      expect(props.keys, isNot(contains('entry_id')));
      for (final value in props.values) {
        expect(value.toString().toLowerCase(), isNot(contains('secret')));
        expect(value.toString().toLowerCase(), isNot(contains('pressure')));
      }
    });
  });

  group('EntryImportanceButton', () {
    testWidgets('marks important from post-save summary', (tester) async {
      final entry = _textEntry(id: 'post1', transcript: _realMoment);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: entry,
              allEntries: [entry],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('entry_importance_mark_post1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('entry_importance_mark_post1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(EntryImportanceStore.isImportant('post1'), isTrue);
      expect(
        find.byKey(const Key('entry_importance_chip_post1')),
        findsOneWidget,
      );
    });

    testWidgets('marks important from archive history row', (tester) async {
      final content = ArchiveHistoryEngine.build(
        entries: [_textEntry(id: 'hist1', transcript: _realMoment)],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(content: content, entryCount: 1),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('entry_importance_mark_hist1')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(EntryImportanceStore.isImportant('hist1'), isTrue);
      expect(
        find.byKey(const Key('entry_importance_chip_hist1')),
        findsOneWidget,
      );
      expect(content.items.single.isImportant, isFalse);
    });
  });

  group('integration untouched', () {
    test('first proof flow still works', () {
      final entries = [
        _textEntry(
          id: '1',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _textEntry(
          id: '2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _textEntry(
          id: '3',
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
      expect(
        EarlyFirstSignalEngine.build(entries: entries)?.showsConfirmedRepeat,
        isTrue,
      );
    });

    test('billing RevenueCat restore signing build files untouched', () {
      const paths = [
        'lib/features/entry_importance/entry_importance_copy.dart',
        'lib/features/entry_importance/entry_importance_store.dart',
        'lib/features/entry_importance/entry_importance_engine.dart',
        'lib/widgets/record/entry_importance_button.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
        expect(content, isNot(contains('build_number')));
      }
    });
  });
}
