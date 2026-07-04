import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_copy.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_engine.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_item.dart';
import 'package:voicememory_mobile/features/early_archive/early_saved_moments_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_history/archive_history_sheet.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _realMoment =
    'I felt pressure to say yes again before checking my capacity today.';

JournalEntry _textEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
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

JournalEntry _degradedVoiceEntry({
  String id = 'v1',
  String transcript = _placeholder,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 20,
      localAudioPath: '/tmp/audio.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
    );

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('ArchiveHistoryEngine', () {
    test('empty state when no entries', () {
      final content = ArchiveHistoryEngine.build(entries: []);
      expect(content.isEmpty, isTrue);
      expect(content.items, isEmpty);
    });

    test('orders most recent first', () {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(
            id: 'older',
            transcript: 'Older moment about lunch with a friend today.',
            createdAt: DateTime(2026, 6, 10, 9),
          ),
          _textEntry(
            id: 'newer',
            transcript: 'Newer moment about errands this afternoon.',
            createdAt: DateTime(2026, 6, 12, 15),
          ),
        ],
      );

      expect(content.items, hasLength(2));
      expect(content.items.first.entryId, 'newer');
      expect(content.items.last.entryId, 'older');
    });

    test('first real entry shows saved only', () {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(id: 'one', transcript: _realMoment),
        ],
      );

      expect(content.items.single.status, ArchiveHistoryStatus.savedOnly);
      expect(content.items.single.previewText, contains('pressure to say yes'));
      expect(content.items.single.evidenceNote, isNull);
      expect(content.items.single.showAddWordsCta, isFalse);
    });

    test('grounded repeat pair can show used as evidence', () {
      final entries = [
        _textEntry(
          id: 'e1',
          transcript:
              'I said yes again even though I was already tired from work today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _textEntry(
          id: 'e2',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];
      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isTrue,
      );

      final content = ArchiveHistoryEngine.build(entries: entries);
      final used = content.items
          .where((item) => item.status == ArchiveHistoryStatus.usedAsEvidence)
          .toList();

      expect(used, hasLength(2));
      expect(
        used.every(
          (item) => item.evidenceNote == ArchiveHistoryCopy.noteUsedAsEvidence,
        ),
        isTrue,
      );
    });

    test('generic test text shows ignored for patterns', () {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(id: 'test', transcript: 'hello checking mic test'),
        ],
      );

      final item = content.items.single;
      expect(item.status, ArchiveHistoryStatus.ignoredForPatterns);
      expect(item.previewText, contains('hello checking mic test'));
      expect(item.evidenceNote, ArchiveHistoryCopy.noteIgnoredForPatterns);
    });

    test('placeholder transcript does not show raw placeholder as preview', () {
      final content = ArchiveHistoryEngine.build(
        entries: [_degradedVoiceEntry()],
      );

      final item = content.items.single;
      expect(item.previewText, ArchiveHistoryCopy.pendingPreview);
      expect(item.previewText, isNot(contains('[draft]')));
      expect(item.previewText, isNot(contains('transcribe when connected')));
    });

    test('pending transcript shows needs your words with add words CTA', () {
      final content = ArchiveHistoryEngine.build(
        entries: [_degradedVoiceEntry(id: 'pending')],
      );

      final item = content.items.single;
      expect(item.status, ArchiveHistoryStatus.needsYourWords);
      expect(item.evidenceNote, ArchiveHistoryCopy.noteNeedsYourWords);
      expect(item.showAddWordsCta, isTrue);
    });

    test('unrelated entries do not claim used as evidence', () {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(
            id: 'a',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
          _textEntry(
            id: 'b',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        ],
      );

      expect(
        content.items.any(
          (item) => item.status == ArchiveHistoryStatus.usedAsEvidence,
        ),
        isFalse,
      );
      expect(
        content.items.every(
          (item) => item.status == ArchiveHistoryStatus.savedOnly,
        ),
        isTrue,
      );
    });
  });

  group('ArchiveHistorySheet', () {
    testWidgets('renders empty state copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(
              content: const ArchiveHistoryContent(items: [], isEmpty: true),
              entryCount: 0,
            ),
          ),
        ),
      );

      expect(find.text(ArchiveHistoryCopy.emptyTitle), findsOneWidget);
      expect(find.text(ArchiveHistoryCopy.emptyBody), findsOneWidget);
    });

    testWidgets('shows at most one add words CTA per row', (tester) async {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _degradedVoiceEntry(id: 'v1'),
          _textEntry(id: 't1', transcript: _realMoment),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(content: content, entryCount: 2),
          ),
        ),
      );

      expect(find.text(ArchiveHistoryCopy.addWordsCta), findsOneWidget);
      expect(
        find.byKey(const Key('archive_history_chip_needs_your_words')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_history_filter_chip_saved_only')),
        findsOneWidget,
      );
    });

    testWidgets('saved row shows status chip and preview', (tester) async {
      final content = ArchiveHistoryEngine.build(
        entries: [_textEntry(id: 'saved', transcript: _realMoment)],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(content: content, entryCount: 1),
          ),
        ),
      );

      expect(find.text(ArchiveHistoryCopy.sheetTitle), findsOneWidget);
      expect(find.text(ArchiveHistoryCopy.sheetSubtitle), findsOneWidget);
      expect(
        find.byKey(const Key('archive_history_chip_saved_only')),
        findsOneWidget,
      );
      expect(find.textContaining('pressure to say yes'), findsOneWidget);
    });

    testWidgets('ignored row shows note without add words CTA', (tester) async {
      final content = ArchiveHistoryEngine.build(
        entries: [
          _textEntry(id: 'ignored', transcript: 'hello checking mic test'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(content: content, entryCount: 1),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_history_chip_ignored_for_patterns')),
        findsOneWidget,
      );
      expect(find.text(ArchiveHistoryCopy.noteIgnoredForPatterns), findsOneWidget);
      expect(find.text(ArchiveHistoryCopy.addWordsCta), findsNothing);
    });

    testWidgets('evidence row shows used as evidence chip and note', (
      tester,
    ) async {
      final entries = [
        _textEntry(
          id: 'e1',
          transcript:
              'I said yes again even though I was already tired from work today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _textEntry(
          id: 'e2',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];
      final content = ArchiveHistoryEngine.build(entries: entries);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHistorySheet(content: content, entryCount: 2),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_history_chip_used_as_evidence')),
        findsNWidgets(2),
      );
      expect(find.text(ArchiveHistoryCopy.noteUsedAsEvidence), findsNWidgets(2));
      expect(find.text(ArchiveHistoryCopy.addWordsCta), findsNothing);
    });
  });

  group('Archive history integration', () {
    testWidgets('view saved moments opens archive history sheet', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(
          _textEntry(
            id: 'a',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
        );
        await AppServices.instance.journalStore.save(
          _textEntry(
            id: 'b',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        );
      });

      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.text(EarlySavedMomentsCopy.viewSavedMomentsCta),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('early_repeat_progress_view_saved_moments_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('archive_history_sheet')), findsOneWidget);
      expect(find.text(ArchiveHistoryCopy.sheetSubtitle), findsOneWidget);
    });

    test('first proof flow still works with archive history engine present', () {
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
      final history = ArchiveHistoryEngine.build(entries: entries);
      expect(history.items, hasLength(3));
      expect(
        history.items.any(
          (item) => item.status == ArchiveHistoryStatus.usedAsEvidence,
        ),
        isTrue,
      );
    });

    test('copy avoids internal analytics and engine labels', () {
      final haystack = ArchiveHistoryCopy.all.join(' ').toLowerCase();
      for (final banned in [
        'revenuecat',
        'quality level',
        'score',
        'debug',
        'analytics',
        'secondsession',
        'earlyfirst',
      ]) {
        expect(haystack, isNot(contains(banned)), reason: banned);
      }
    });
  });
}
