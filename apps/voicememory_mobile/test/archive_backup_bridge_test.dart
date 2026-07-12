import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_analytics.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_copy.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_dismiss_store.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_engine.dart';
import 'package:voicememory_mobile/features/archive_backup_bridge/archive_backup_bridge_model.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro/archive_backup_bridge_card.dart';
import 'package:voicememory_mobile/widgets/pro/archive_backup_bridge_sheet.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        id: 'e1',
        transcript: _strongRepeat,
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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

ArchiveBackupBridgeContext _context({
  List<JournalEntry> entries = const [],
  int entryCount = 0,
  bool isPro = false,
  bool dismissed = false,
  ArchiveBackupBridgeSurface surface = ArchiveBackupBridgeSurface.settings,
  bool isZeroEntryState = false,
  bool isFirstRecordingState = false,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool firstProofTruthQuestionActive = false,
  bool whatChangedQuestionActive = false,
  bool? hasReportPreview,
  bool? hasSeenProof,
}) {
  return ArchiveBackupBridgeEngine.buildContext(
    surface: surface,
    entryCount: entryCount,
    isPro: isPro,
    dismissed: dismissed,
    entries: entries,
    hasReportPreview: hasReportPreview,
    hasSeenProof: hasSeenProof,
    isZeroEntryState: isZeroEntryState,
    isFirstRecordingState: isFirstRecordingState,
    isDegradedTranscriptState: isDegradedTranscriptState,
    isPostSaveDegradedState: isPostSaveDegradedState,
    firstProofTruthQuestionActive: firstProofTruthQuestionActive,
    whatChangedQuestionActive: whatChangedQuestionActive,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    analyticsEvents.clear();
    ArchiveBackupBridgeAnalytics.resetForTest();
    ArchiveBackupBridgeAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/archive_backup_bridge/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/archive_backup_bridge/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await ArchiveBackupBridgeDismissStore.resetForTest();
  });

  tearDown(() {
    ArchiveBackupBridgeAnalytics.resetForTest();
    analyticsEvents.clear();
  });

  group('ArchiveBackupBridgeCopy', () {
    test('defines required copy', () {
      expect(ArchiveBackupBridgeCopy.cardTitle, 'Do not lose this archive');
      expect(
        ArchiveBackupBridgeCopy.cardBody,
        contains('evidence over time'),
      );
      expect(
        ArchiveBackupBridgeCopy.plannedProAreas,
        contains('planned Pro areas'),
      );
      expect(
        ArchiveBackupBridgeCopy.deviceBackupToday,
        contains('keep your device backed up'),
      );
    });

    test('does not claim backup is live', () {
      for (final line in ArchiveBackupBridgeCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('your archive is backed up')));
        expect(lower, isNot(contains('sync is active')));
        expect(lower, isNot(contains('cloud backup included')));
        expect(lower, isNot(contains('recovered automatically')));
      }
    });

    test('mentions planned backup safely', () {
      expect(
        ArchiveBackupBridgeCopy.plannedProAreas.toLowerCase(),
        contains('planned'),
      );
      expect(
        ArchiveBackupBridgeCopy.proPreservation.toLowerCase(),
        contains('longer proof trail'),
      );
    });

    test('does not claim therapy or medical benefit', () {
      for (final line in ArchiveBackupBridgeCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('therapy')));
        expect(lower, isNot(contains('diagnosis')));
        expect(lower, isNot(contains('treatment')));
        expect(lower, isNot(contains('medical')));
        expect(lower, isNot(contains('clinical')));
      }
    });
  });

  group('ArchiveBackupBridgeEngine', () {
    test('hidden before archive has value', () {
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: [_entry(id: 'a', transcript: 'Random note one')],
            entryCount: 1,
          ),
        ),
        isFalse,
      );
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: [
              _entry(id: 'a', transcript: 'Random note one'),
              _entry(id: 'b', transcript: 'Random note two'),
            ],
            entryCount: 2,
            hasSeenProof: false,
            hasReportPreview: false,
          ),
        ),
        isFalse,
      );
    });

    test('shown after confirmed repeat evidence', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          ArchiveBackupBridgeContext(
            surface: ArchiveBackupBridgeSurface.settings,
            entryCount: entries.length,
            isPro: false,
            dismissed: false,
            hasConfirmedRepeat: true,
            hasReportPreview: true,
            hasSeenProof: true,
            isZeroEntryState: false,
            isFirstRecordingState: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            firstProofTruthQuestionActive: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
          ),
        ),
        isTrue,
      );
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
    });

    test('shown after report preview evidence', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.hasReportPreview(entries: entries),
        isTrue,
      );
    });

    test('settings placement works', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          ArchiveBackupBridgeContext(
            surface: ArchiveBackupBridgeSurface.settings,
            entryCount: entries.length,
            isPro: true,
            dismissed: false,
            hasConfirmedRepeat: true,
            hasReportPreview: true,
            hasSeenProof: true,
            isZeroEntryState: false,
            isFirstRecordingState: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            firstProofTruthQuestionActive: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
          ),
        ),
        isTrue,
      );
    });

    test('archive placement hidden for Pro users', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          ArchiveBackupBridgeContext(
            surface: ArchiveBackupBridgeSurface.archivePatterns,
            entryCount: entries.length,
            isPro: true,
            dismissed: false,
            hasConfirmedRepeat: true,
            hasReportPreview: true,
            hasSeenProof: true,
            isZeroEntryState: false,
            isFirstRecordingState: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            firstProofTruthQuestionActive: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
          ),
        ),
        isFalse,
      );
    });

    test('blocked during active review questions', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            firstProofTruthQuestionActive: true,
            hasReportPreview: true,
            hasSeenProof: true,
          ),
        ),
        isFalse,
      );
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            whatChangedQuestionActive: true,
            hasReportPreview: true,
            hasSeenProof: true,
          ),
        ),
        isFalse,
      );
    });

    test('blocked during degraded transcript', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            isDegradedTranscriptState: true,
            hasReportPreview: true,
            hasSeenProof: true,
          ),
        ),
        isFalse,
      );
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            isPostSaveDegradedState: true,
            hasReportPreview: true,
            hasSeenProof: true,
          ),
        ),
        isFalse,
      );
    });

    test('blocked during pattern review inbox items', () {
      final entries = _threeRelatedEntries();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
          ),
        ),
        isFalse,
      );
    });

    test('hidden when dismissed', () async {
      final entries = _threeRelatedEntries();
      await ArchiveBackupBridgeDismissStore.dismiss();
      expect(
        ArchiveBackupBridgeEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            dismissed: ArchiveBackupBridgeDismissStore.isDismissed(),
            hasReportPreview: true,
            hasSeenProof: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('ArchiveBackupBridgeCard', () {
    testWidgets('CTA opens sheet', (tester) async {
      final entries = _threeRelatedEntries();
      final contextData = ArchiveBackupBridgeContext(
        surface: ArchiveBackupBridgeSurface.settings,
        entryCount: entries.length,
        isPro: false,
        dismissed: false,
        hasConfirmedRepeat: true,
        hasReportPreview: true,
        hasSeenProof: true,
        isZeroEntryState: false,
        isFirstRecordingState: false,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: false,
        firstProofTruthQuestionActive: false,
        whatChangedQuestionActive: false,
        patternReviewInboxHasActiveItems: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveBackupBridgeCard(
              contextData: contextData,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_backup_bridge_card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('archive_backup_bridge_cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('archive_backup_bridge_sheet_title')),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveBackupBridgeCopy.plannedProAreas),
        findsOneWidget,
      );
      expect(
        analyticsEvents.any(
          (event) => event.event == ArchiveBackupBridgeAnalytics.ctaTappedEvent,
        ),
        isTrue,
      );
    });
  });

  group('ArchiveBackupBridgeSheet', () {
    testWidgets('includes safe preservation copy', (tester) async {
      final contextData = ArchiveBackupBridgeContext(
        surface: ArchiveBackupBridgeSurface.archivePatterns,
        entryCount: 3,
        isPro: false,
        dismissed: false,
        hasConfirmedRepeat: true,
        hasReportPreview: true,
        hasSeenProof: true,
        isZeroEntryState: false,
        isFirstRecordingState: false,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: false,
        firstProofTruthQuestionActive: false,
        whatChangedQuestionActive: false,
        patternReviewInboxHasActiveItems: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveBackupBridgeSheet(
              contextData: contextData,
              onSeePro: () {},
            ),
          ),
        ),
      );

      expect(
        find.text(ArchiveBackupBridgeCopy.deviceBackupToday),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveBackupBridgeCopy.plannedProAreas),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not look like'),
        findsNothing,
      );
    });
  });
}
