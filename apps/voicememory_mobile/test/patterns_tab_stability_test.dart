import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/design/empty_archive_experience.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:voicememory_mobile/features/patterns/patterns_tab_stability.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/archive_belief_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_first_archive_view.dart';

const _analyzeUnavailableTranscript =
    'I felt pressure before saying yes again today.';

JournalEntry _analyzeUnavailableEntry({
  String id = 'e1',
  DateTime? createdAt,
  String? transcript,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript: transcript ?? _analyzeUnavailableTranscript,
    durationSeconds: 24,
    localAudioPath: '/tmp/$id.m4a',
    syncStatus: SyncStatus.pendingUpload,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

JournalEntry _transcriptEntry({
  String id = 'e1',
  String? transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript:
        transcript ??
        'A long enough transcript to count as a saved reflection.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

JournalEntry _degradedEntry({String id = 'd1', DateTime? createdAt}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 10, 9),
    transcript: '',
    durationSeconds: 2,
    reflection: const Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

Future<void> _resetServices() async {
  await AppServices.resetForTest(
    journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
    prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
    skipRevenueCat: true,
  );
}

Future<void> _pumpPatternsTab(
  WidgetTester tester, {
  Finder? waitFor,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ArchiveBeliefScreen(key: UniqueKey()),
    ),
  );
  await tester.pump();
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (waitFor != null && waitFor.evaluate().isNotEmpty) {
      return;
    }
    if (waitFor == null &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  group('PatternsNoClearPatternView', () {
    testWidgets('shows required empty copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PatternsNoClearPatternView()),
        ),
      );
      await tester.pump();

      expect(
        find.text(ConsumerUiCopy.patternsNoClearPatternTitle),
        findsOneWidget,
      );
      expect(
        find.text(ConsumerUiCopy.patternsNoClearPatternBody),
        findsOneWidget,
      );
    });
  });

  group('Archive evidence fixtures', () {
    test('three degraded entries count as intentional empty archive', () {
      final entries = [
        _degradedEntry(id: 'd1'),
        _degradedEntry(id: 'd2', createdAt: DateTime(2026, 6, 11)),
        _degradedEntry(id: 'd3', createdAt: DateTime(2026, 6, 12)),
      ];
      expect(archiveEvidenceReflectionCount(entries), 0);
      expect(isIntentionalEmptyArchive(entries), isTrue);
    });

    test('five analyze-unavailable entries still count as evidence', () {
      final entries = List.generate(
        5,
        (i) => _analyzeUnavailableEntry(
          id: 'a$i',
          createdAt: DateTime(2026, 6, 8 + i, 10),
        ),
      );
      expect(archiveEvidenceReflectionCount(entries), 5);
      expect(isIntentionalEmptyArchive(entries), isFalse);
    });

    test('hasRenderablePatternInsight rejects null belief snapshot', () {
      expect(
        PatternsTabStability.hasRenderablePatternInsight(
          beliefs: null,
          strongest: null,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveBeliefScreen — patterns tab stability', () {
    testWidgets('renders with zero entries', (tester) async {
      await _pumpPatternsTab(tester);

      expect(find.byType(PatternsEmptyView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with one successful transcript entry', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_transcriptEntry());
      });

      await _pumpPatternsTab(tester);

      expect(find.byType(PatternsFirstArchiveView), findsOneWidget);
      expect(
        find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with two transcript entries', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _transcriptEntry(id: 'e1', createdAt: DateTime(2026, 6, 11, 10)),
        );
        await AppServices.instance.journalStore.save(
          _transcriptEntry(id: 'e2', createdAt: DateTime(2026, 6, 12, 10)),
        );
        final loaded = await AppServices.instance.journal.loadAll();
        expect(loaded.length, 2);
      });

      await _pumpPatternsTab(
        tester,
        waitFor: find.byKey(const Key('archive_belief_thread_card')),
      );

      expect(find.byType(PatternsFirstArchiveView), findsNothing);
      expect(find.byType(PatternsEmptyView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders when pattern snapshot is null (no evidence)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_degradedEntry(id: 'd1'));
        await AppServices.instance.journalStore.save(
          _degradedEntry(id: 'd2', createdAt: DateTime(2026, 6, 11)),
        );
        await AppServices.instance.journalStore.save(
          _degradedEntry(id: 'd3', createdAt: DateTime(2026, 6, 12)),
        );
        final loaded = await AppServices.instance.journal.loadAll();
        expect(loaded.length, 3);
      });

      await _pumpPatternsTab(
        tester,
        waitFor: find.byType(PatternsNoClearPatternView),
      );

      expect(find.byType(PatternsNoClearPatternView), findsOneWidget);
      expect(
        find.text(ConsumerUiCopy.patternsNoClearPatternTitle),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with two transcript entries and null insight fields', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _transcriptEntry(
            id: 'e1',
            transcript: 'I felt rushed before the meeting started today.',
            createdAt: DateTime(2026, 6, 11, 10),
          ),
        );
        await AppServices.instance.journalStore.save(
          _transcriptEntry(
            id: 'e2',
            transcript: 'I felt rushed again when plans changed tonight.',
            createdAt: DateTime(2026, 6, 12, 10),
          ),
        );
        final loaded = await AppServices.instance.journal.loadAll();
        expect(loaded.length, 2);
      });

      await _pumpPatternsTab(
        tester,
        waitFor: find.byKey(const Key('archive_belief_thread_card')),
      );

      final exception = tester.takeException();
      if (exception != null) {
        expect(
          exception.toString(),
          isNot(contains('Null check operator used on a null value')),
        );
      }
      expect(find.byType(PatternsNoClearPatternView), findsNothing);
      expect(find.byType(PatternsFirstArchiveView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'five transcript entries with analyze unavailable do not null-crash',
      (tester) async {
        await tester.runAsync(() async {
          for (var i = 0; i < 5; i++) {
            await AppServices.instance.journalStore.save(
              _analyzeUnavailableEntry(
                id: 'a$i',
                createdAt: DateTime(2026, 6, 8 + i, 10),
                transcript:
                    'I felt pressure before saying yes again on day ${i + 1}.',
              ),
            );
          }
          final loaded = await AppServices.instance.journal.loadAll();
          expect(loaded.length, 5);
        });

        await tester.binding.setSurfaceSize(const Size(390, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: ArchiveBeliefScreen(key: UniqueKey()),
          ),
        );
        await tester.pump();

        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          final exception = tester.takeException();
          if (exception != null) {
            expect(
              exception.toString(),
              isNot(contains('Null check operator used on a null value')),
            );
          }
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            break;
          }
        }

        expect(tester.takeException(), isNull);
        expect(find.byType(PatternsFirstArchiveView), findsNothing);
        expect(find.byType(PatternsEmptyView), findsNothing);
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    test('logging helpers emit required prefixes', () {
      expect(
        () => PatternsTabStability.logTabBuild(
          entryCount: 2,
          patternCount: 0,
        ),
        returnsNormally,
      );
      expect(
        () => PatternsTabStability.logEmptyState(
          'null_belief_snapshot_or_field',
        ),
        returnsNormally,
      );
      expect(
        () => PatternsTabStability.logBuildFailed('test'),
        returnsNormally,
      );
    });
  });
}
