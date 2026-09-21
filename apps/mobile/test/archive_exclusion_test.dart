import 'dart:io';

import 'package:archiveme_mobile/features/archive_controls/archive_control_analytics.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_control_copy.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_engine.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_store.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_engine.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_item.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/local_privacy_data_controls.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_controls/archive_pattern_exclusion_actions.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    ArchiveControlAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await ArchiveExclusionStore.resetForTest();
  });

  tearDown(() => sandbox.dispose());

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

  tearDown(() => sandbox.dispose());
  group('ArchiveExclusionEngine', () {
    test('exclude confirmation stores exclusion', () async {
      await seedEntries(_threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      );
      expect(patternKey, isNotNull);

      final result = await ArchiveExclusionEngine.excludeFromPattern(
        entryId: 'e3',
        patternKey: patternKey!,
        source: 'test',
      );
      expect(result.excluded, isTrue);
      expect(
        ArchiveExclusionStore.isExcluded(entryId: 'e3', patternKey: patternKey),
        isTrue,
      );
    });

    test('excluded moment disappears from pattern detail evidence', () async {
      await seedEntries(_threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      )!;
      await ArchiveExclusionEngine.excludeFromPattern(
        entryId: 'e3',
        patternKey: patternKey,
        source: 'test',
      );

      final detail = PatternDetailEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(
        detail?.savedMoments.any((m) => m.entryId == 'e3') ?? false,
        isFalse,
      );
    });

    test('excluded moment does not count toward first proof', () async {
      await seedEntries(_threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      )!;
      await ArchiveExclusionEngine.excludeFromPattern(
        entryId: 'e3',
        patternKey: patternKey,
        source: 'test',
      );

      expect(FirstProofPayoffEngine.build(entries: entries), isNull);
    });

    test('excluding can safely drop pattern below threshold', () async {
      await seedEntries(_threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      )!;
      await ArchiveExclusionEngine.excludeFromPattern(
        entryId: 'e3',
        patternKey: patternKey,
        source: 'test',
      );

      expect(
        PatternDetailEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isFalse,
      );
    });
  });

  group('ArchivePatternExclusionActions', () {
    testWidgets('cancel does not exclude', (tester) async {
      await seedEntriesForWidget(tester, _threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      )!;

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

      final confirmFuture = ArchivePatternExclusionActions.confirmExclude(
        sheetContext,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(ArchiveControlCopy.excludeDialogTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('archive_pattern_exclude_cancel')));
      await tester.pump();
      expect(await confirmFuture, isFalse);

      expect(
        ArchiveExclusionStore.isExcluded(entryId: 'e1', patternKey: patternKey),
        isFalse,
      );
    });
  });

  group('PatternDetailSheet', () {
    testWidgets('exclude action appears on pattern detail evidence row', (
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
        find.byKey(const Key('pattern_detail_exclude_from_pattern_0')),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveControlCopy.excludeFromPatternButton),
        findsWidgets,
      );
    });
  });

  group('Archive history', () {
    test('excluded moment stays in saved moments with chip', () async {
      await seedEntries(_threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      )!;
      await ArchiveExclusionEngine.excludeFromPattern(
        entryId: 'e3',
        patternKey: patternKey,
        source: 'test',
      );

      final history = ArchiveHistoryEngine.build(entries: entries);
      expect(history.items.any((item) => item.entryId == 'e3'), isTrue);
      final excluded = history.items.firstWhere((item) => item.entryId == 'e3');
      expect(excluded.status, ArchiveHistoryStatus.excludedFromPattern);
    });
  });

  group('Archive reset', () {
    test('archive reset clears exclusions', () async {
      await seedEntries(_threeRelatedEntries());
      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      )!;
      await ArchiveExclusionEngine.excludeFromPattern(
        entryId: 'e1',
        patternKey: patternKey,
        source: 'test',
      );
      expect(
        ArchiveExclusionStore.isExcluded(entryId: 'e1', patternKey: patternKey),
        isTrue,
      );

      await LocalPrivacyDataControls.instance().clearLocalArchive();

      await ArchiveExclusionStore.ensureLoaded();
      expect(
        ArchiveExclusionStore.isExcluded(entryId: 'e1', patternKey: patternKey),
        isFalse,
      );
    });
  });

  group('ArchiveControlAnalytics', () {
    test('payload excludes transcript and pattern text', () async {
      await seedEntries(_threeRelatedEntries());
      final captured = <({String event, Map<String, Object> props})>[];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest((event, props) {
        captured.add((event: event, props: props));
      });

      final entries = await AppServices.instance.journal.loadAll();
      final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
        entries,
      )!;
      await ArchiveExclusionEngine.excludeFromPattern(
        entryId: 'e1',
        patternKey: patternKey,
        source: 'test',
      );

      final excludedEvents = captured
          .where(
            (e) =>
                e.event == ArchiveControlAnalytics.patternEvidenceExcludedEvent,
          )
          .toList();
      expect(excludedEvents.length, 1);
      const allowedKeys = {'source', 'entry_count', 'has_confirmed_repeat'};
      expect(excludedEvents.first.props.keys.toSet(), allowedKeys);
      final values = excludedEvents.first.props.values
          .map((v) => v.toString().toLowerCase())
          .join(' ');
      expect(values, isNot(contains('said yes')));
      expect(values, isNot(contains('capacity')));
    });
  });

  group('Protected areas', () {
    test('feature files avoid billing and signing surfaces', () {
      const banned = ['RevenueCat', 'Purchases.', 'CFBundleVersion', 'signing'];
      final files = [
        'lib/features/archive_controls/archive_exclusion_model.dart',
        'lib/features/archive_controls/archive_exclusion_store.dart',
        'lib/features/archive_controls/archive_exclusion_engine.dart',
        'lib/widgets/archive_controls/archive_pattern_exclusion_actions.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(
            text.contains(token),
            isFalse,
            reason: '$path must not reference $token',
          );
        }
      }
    });
  });
}