import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_controls/archive_control_analytics.dart';
import 'package:voicememory_mobile/features/archive_controls/archive_control_copy.dart';
import 'package:voicememory_mobile/features/archive_controls/archive_control_engine.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:voicememory_mobile/features/transcript_correction/transcript_correction_gate.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_controls/archive_moment_actions_sheet.dart';
import 'package:voicememory_mobile/widgets/archive_history/archive_history_sheet.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_detail_sheet.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

void main() {
  setUp(() async {
    ArchiveControlAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/archive_controls/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/archive_controls/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  Future<void> seedEntries(List<JournalEntry> entries) async {
    for (final entry in entries) {
      await AppServices.instance.journalStore.save(entry);
    }
  }

  Future<void> seedEntriesForWidget(
    WidgetTester tester,
    List<JournalEntry> entries,
  ) async {
    await tester.runAsync(() async {
      for (final entry in entries) {
        await AppServices.instance.journalStore.save(entry);
      }
    });
  }

  group('ArchiveControlEngine', () {
    test('wasUsedAsEvidence identifies evidence moments', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveControlEngine.wasUsedAsEvidence(
          entryId: 'e1',
          entries: entries,
        ),
        isTrue,
      );
      expect(
        ArchiveControlEngine.wasUsedAsEvidence(
          entryId: 'missing',
          entries: entries,
        ),
        isFalse,
      );
    });

    test('deleteMoment removes entry and recomputes archive history', () async {
      await seedEntries(_threeRelatedEntries());
      final result = await ArchiveControlEngine.deleteMoment(
        entryId: 'e3',
        source: 'test',
      );
      expect(result.deleted, isTrue);
      expect(result.entryCount, 2);
      expect(result.wasEvidence, isTrue);

      final remaining = await AppServices.instance.journal.loadAll();
      expect(remaining.map((e) => e.id).toSet(), {'e1', 'e2'});
      final history = ArchiveHistoryEngine.build(entries: remaining);
      expect(history.items.any((item) => item.entryId == 'e3'), isFalse);
    });

    test('delete confirmation removes moment', () async {
      await seedEntries(_threeRelatedEntries());
      final result = await ArchiveControlEngine.deleteMoment(
        entryId: 'e2',
        source: 'test',
      );
      expect(result.deleted, isTrue);
      final remaining = await AppServices.instance.journal.loadAll();
      expect(remaining.length, 2);
      expect(remaining.any((e) => e.id == 'e2'), isFalse);
    });

    test('deleting evidence can drop pattern below threshold', () async {
      await seedEntries(_threeRelatedEntries());
      await ArchiveControlEngine.deleteMoment(entryId: 'e3', source: 'test');
      final remaining = await AppServices.instance.journal.loadAll();
      expect(
        PatternDetailEngine.build(
          entries: remaining,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
      expect(
        FirstProofPayoffEngine.build(entries: remaining),
        isNull,
      );
    });
  });

  group('ArchiveMomentDeleteActions', () {
    testWidgets('cancel does not remove moment', (tester) async {
      await seedEntriesForWidget(tester, _threeRelatedEntries());

      late BuildContext sheetContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              sheetContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final confirmFuture = ArchiveMomentDeleteActions.confirmDelete(
        sheetContext,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(ArchiveControlCopy.deleteDialogTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('archive_moment_delete_cancel')));
      await tester.pump();
      expect(await confirmFuture, isFalse);

      final remaining = await AppServices.instance.journal.loadAll();
      expect(remaining.length, 3);
    });

    testWidgets('confirm delete returns true when confirmed', (tester) async {
      late BuildContext sheetContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              sheetContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final confirmFuture = ArchiveMomentDeleteActions.confirmDelete(
        sheetContext,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('archive_moment_delete_confirm')));
      await tester.pump();
      expect(await confirmFuture, isTrue);
    });
  });

  group('ArchiveHistorySheet', () {
    testWidgets('delete action appears in archive history row', (tester) async {
      await seedEntriesForWidget(tester, _threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final content = ArchiveHistoryEngine.build(entries: entries);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(
              content: content,
              entryCount: entries.length,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_history_delete_moment_e1')),
        findsOneWidget,
      );
      expect(find.text(ArchiveControlCopy.deleteMomentButton), findsWidgets);
    });
  });

  group('PatternDetailSheet', () {
    testWidgets('delete action appears on pattern detail evidence row', (
      tester,
    ) async {
      await seedEntriesForWidget(tester, _threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final buildInput = PatternDetailBuildInput(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      final detail = buildInput.buildDetail();
      expect(detail, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternDetailSheet(
              detail: detail!,
              buildInput: buildInput,
              entryCount: entries.length,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pattern_detail_delete_moment_0')),
        findsOneWidget,
      );
      expect(find.text(ArchiveControlCopy.deleteMomentButton), findsWidgets);
    });

    test('deleting evidence shows safe fallback copy via rebuild input', () async {
      await seedEntries(_threeRelatedEntries());
      await ArchiveControlEngine.deleteMoment(entryId: 'e3', source: 'test');
      final remaining = await AppServices.instance.journal.loadAll();
      expect(
        PatternDetailBuildInput(
          entries: remaining,
          viewingConfirmedRepeatOrTimeline: true,
        ).buildDetail(),
        isNull,
      );
    });
  });

  group('ArchiveControlAnalytics', () {
    test('payload excludes transcript text', () async {
      await seedEntries(_threeRelatedEntries());
      final captured = <({String event, Map<String, Object> props})>[];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest((event, props) {
        captured.add((event: event, props: props));
      });

      await ArchiveControlEngine.deleteMoment(entryId: 'e1', source: 'test');

      final deletedEvents = captured
          .where((e) => e.event == ArchiveControlAnalytics.deletedEvent)
          .toList();
      expect(deletedEvents.length, 1);
      const allowedKeys = {'source', 'entry_count', 'was_evidence'};
      expect(deletedEvents.first.props.keys.toSet(), allowedKeys);
      final values = deletedEvents.first.props.values
          .map((v) => v.toString().toLowerCase())
          .join(' ');
      expect(values, isNot(contains('said yes')));
      expect(values, isNot(contains('capacity')));
    });
  });

  group('Transcript correction still available', () {
    test('correction gate still allows related entries', () {
      final entry = _threeRelatedEntries().first;
      expect(TranscriptCorrectionGate.entryAllowsCorrection(entry), isTrue);
    });
  });

  group('Protected areas', () {
    test('feature files avoid billing and signing surfaces', () {
      const banned = ['RevenueCat', 'Purchases.', 'CFBundleVersion', 'signing'];
      final files = [
        'lib/features/archive_controls/archive_control_copy.dart',
        'lib/features/archive_controls/archive_control_engine.dart',
        'lib/features/archive_controls/archive_control_analytics.dart',
        'lib/widgets/archive_controls/archive_moment_actions_sheet.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(text.contains(token), isFalse, reason: '$path must not reference $token');
        }
      }
    });
  });
}
