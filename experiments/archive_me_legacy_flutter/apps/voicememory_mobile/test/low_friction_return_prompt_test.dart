import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/low_friction_return/low_friction_return_analytics.dart';
import 'package:voicememory_mobile/features/low_friction_return/low_friction_return_copy.dart';
import 'package:voicememory_mobile/features/low_friction_return/low_friction_return_engine.dart';
import 'package:voicememory_mobile/features/low_friction_return/low_friction_return_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/low_friction_return_card.dart';

import 'support/record_screen_layout_assertions.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/low_friction_return/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  String transcript = 'Work pressure showed up again today.',
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
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

Map<String, Object> _baseVisibility({
  bool isReady = true,
  bool isRecording = false,
  bool isPostSave = false,
  bool isDegradedTranscriptState = false,
  bool firstProofPayoffVisible = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool isPermissionBlocked = false,
  int entryCount = 0,
  List<JournalEntry> entries = const [],
  bool dismissedForToday = false,
}) => {
  'isReady': isReady,
  'isRecording': isRecording,
  'isPostSave': isPostSave,
  'isDegradedTranscriptState': isDegradedTranscriptState,
  'firstProofPayoffVisible': firstProofPayoffVisible,
  'whatChangedQuestionActive': whatChangedQuestionActive,
  'patternReviewInboxHasActiveItems': patternReviewInboxHasActiveItems,
  'isPermissionBlocked': isPermissionBlocked,
  'entryCount': entryCount,
  'entries': entries,
  'dismissedForToday': dismissedForToday,
};

bool _shouldShow(Map<String, Object> args) =>
    LowFrictionReturnEngine.shouldShow(
      isReady: args['isReady']! as bool,
      isRecording: args['isRecording']! as bool,
      isPostSave: args['isPostSave']! as bool,
      isDegradedTranscriptState: args['isDegradedTranscriptState']! as bool,
      firstProofPayoffVisible: args['firstProofPayoffVisible']! as bool,
      whatChangedQuestionActive: args['whatChangedQuestionActive']! as bool,
      patternReviewInboxHasActiveItems:
          args['patternReviewInboxHasActiveItems']! as bool,
      isPermissionBlocked: args['isPermissionBlocked']! as bool,
      entryCount: args['entryCount']! as int,
      entries: args['entries']! as List<JournalEntry>,
      dismissedForToday: args['dismissedForToday']! as bool,
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  var saveOneSentenceTapped = false;
  String? selectedPrompt;

  setUp(() async {
    LowFrictionReturnAnalytics.resetForTest();
    LowFrictionReturnAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    saveOneSentenceTapped = false;
    selectedPrompt = null;
    await LowFrictionReturnStore.resetForTest(_MemoryPrefs());
  });

  tearDown(LowFrictionReturnAnalytics.resetForTest);

  group('LowFrictionReturnEngine visibility', () {
    test('zero-entry user sees card', () {
      expect(_shouldShow(_baseVisibility(entryCount: 0)), isTrue);
    });

    test('early user sees card', () {
      expect(_shouldShow(_baseVisibility(entryCount: 7)), isTrue);
    });

    test('users over 7 entries do not see card by default', () {
      final now = DateTime(2026, 6, 12, 15);
      expect(
        LowFrictionReturnEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 8,
          entries: [_entry(id: 'e1', createdAt: DateTime(2026, 6, 12, 10))],
          dismissedForToday: false,
          now: now,
        ),
        isFalse,
      );
    });

    test('users over 7 entries see card when not recorded today', () {
      final now = DateTime(2026, 6, 12, 15);
      expect(
        LowFrictionReturnEngine.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 8,
          entries: [_entry(id: 'e1', createdAt: DateTime(2026, 6, 10, 12))],
          dismissedForToday: false,
          now: now,
        ),
        isTrue,
      );
    });

    test('hidden while recording', () {
      expect(
        _shouldShow(_baseVisibility(isRecording: true, entryCount: 2)),
        isFalse,
      );
    });

    test('hidden post-save', () {
      expect(
        _shouldShow(_baseVisibility(isPostSave: true, entryCount: 2)),
        isFalse,
      );
    });

    test('hidden during first proof payoff', () {
      expect(
        _shouldShow(
          _baseVisibility(firstProofPayoffVisible: true, entryCount: 2),
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      expect(
        _shouldShow(
          _baseVisibility(whatChangedQuestionActive: true, entryCount: 2),
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox active item', () {
      expect(
        _shouldShow(
          _baseVisibility(
            patternReviewInboxHasActiveItems: true,
            entryCount: 2,
          ),
        ),
        isFalse,
      );
    });

    test('hidden when skipped for today', () {
      expect(
        _shouldShow(_baseVisibility(entryCount: 2, dismissedForToday: true)),
        isFalse,
      );
    });
  });

  group('LowFrictionReturnCard', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      LowFrictionReturnStore? store,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LowFrictionReturnCard.test(
                source: 'test',
                entryCount: 2,
                store: store,
                onSaveOneSentence: () => saveOneSentenceTapped = true,
                onPromptSelected: (prompt) => selectedPrompt = prompt,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders Nothing to say today?', (tester) async {
      await pumpCard(tester);
      expect(find.text(LowFrictionReturnCopy.title), findsOneWidget);
    });

    testWidgets('renders You do not need a perfect entry', (tester) async {
      await pumpCard(tester);
      expect(find.text(LowFrictionReturnCopy.body), findsOneWidget);
    });

    testWidgets('renders not forced daily journaling', (tester) async {
      await pumpCard(tester);
      expect(find.text(LowFrictionReturnCopy.permissionLine), findsOneWidget);
    });

    testWidgets('renders Save one sentence', (tester) async {
      await pumpCard(tester);
      expect(
        find.text(LowFrictionReturnCopy.saveOneSentenceAction),
        findsOneWidget,
      );
    });

    testWidgets('renders Use a tiny prompt', (tester) async {
      await pumpCard(tester);
      expect(
        find.text(LowFrictionReturnCopy.useTinyPromptAction),
        findsOneWidget,
      );
    });

    testWidgets('renders Skip today', (tester) async {
      await pumpCard(tester);
      expect(find.text(LowFrictionReturnCopy.skipTodayAction), findsOneWidget);
    });

    testWidgets('tiny prompts expand', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('low_friction_return_use_tiny_prompt')),
      );
      await tester.pump();

      for (final prompt in LowFrictionReturnPromptType.all) {
        expect(
          find.text(LowFrictionReturnCopy.promptTextFor(prompt)),
          findsOneWidget,
        );
      }
    });

    testWidgets('selecting prompt shows Start with one sentence', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('low_friction_return_use_tiny_prompt')),
      );
      await tester.pumpAndSettle();
      final promptLabel = LowFrictionReturnCopy.promptTextFor(
        LowFrictionReturnPromptType.whatHelped,
      );
      await tester.ensureVisible(find.text(promptLabel));
      await tester.tap(find.text(promptLabel));
      await tester.pumpAndSettle();

      expect(
        find.text(LowFrictionReturnCopy.afterPromptSelected),
        findsOneWidget,
      );
      expect(selectedPrompt, promptLabel);
    });

    testWidgets('skip shows Skipped for today', (tester) async {
      final prefs = _MemoryPrefs();
      await LowFrictionReturnStore.resetForTest(prefs);
      await pumpCard(tester, store: LowFrictionReturnStore.forPrefs(prefs));

      await tester.tap(find.byKey(const Key('low_friction_return_skip_today')));
      await tester.pumpAndSettle();

      expect(find.text(LowFrictionReturnCopy.afterSkip), findsOneWidget);
      expect(
        find.byKey(const Key('low_friction_return_save_one_sentence')),
        findsNothing,
      );
      expect(LowFrictionReturnStore.isDismissedToday, isTrue);
    });

    testWidgets('save one sentence uses callback without routing', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('low_friction_return_save_one_sentence')),
      );
      await tester.pump();

      expect(saveOneSentenceTapped, isTrue);
      expect(find.byType(Navigator), findsWidgets);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('low_friction_return_use_tiny_prompt')),
      );
      await tester.pump();
      await tester.tap(
        find.text(
          LowFrictionReturnCopy.promptTextFor(
            LowFrictionReturnPromptType.whatChanged,
          ),
        ),
      );
      await tester.pump();

      expect(analyticsEvents, isNotEmpty);
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == LowFrictionReturnAnalytics.seenEvent,
      );
      expect(seen.props.keys, containsAll(['source', 'entry_count']));
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('body')));

      final action = analyticsEvents.firstWhere(
        (event) => event.event == LowFrictionReturnAnalytics.actionTappedEvent,
      );
      expect(action.props['action_type'], 'use_tiny_prompt');

      final prompt = analyticsEvents.firstWhere(
        (event) =>
            event.event == LowFrictionReturnAnalytics.promptSelectedEvent,
      );
      expect(prompt.props['prompt_type'], 'what_changed');
    });
  });

  group('Low friction return copy guard', () {
    test('no streak pressure copy', () {
      final blob = LowFrictionReturnCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('streak')));
      expect(blob, isNot(contains('day in a row')));
      expect(blob, isNot(contains('keep your streak')));
    });

    test('no daily requirement copy', () {
      final blob = LowFrictionReturnCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('must record every day')));
      expect(blob, isNot(contains('should record every day')));
      expect(blob, contains('not forced daily journaling'));
      expect(
        LowFrictionReturnCopy.corePositioning.toLowerCase(),
        contains('do not need to record every day'),
      );
    });

    test('no therapy/diagnosis/treatment claims', () {
      for (final line in LowFrictionReturnCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });

    test('feature files avoid billing surfaces', () {
      for (final path in [
        'lib/features/low_friction_return/low_friction_return_copy.dart',
        'lib/features/low_friction_return/low_friction_return_engine.dart',
        'lib/features/low_friction_return/low_friction_return_analytics.dart',
        'lib/widgets/record/low_friction_return_card.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('revenuecat')));
        expect(source, isNot(contains('restore purchases')));
        expect(source, isNot(contains('subscription')));
      }
    });

    test('does not change evidence classification', () {
      for (final path in [
        'lib/features/low_friction_return/low_friction_return_engine.dart',
        'lib/widgets/record/low_friction_return_card.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('ArchiveEvidenceQuality')));
        expect(source, isNot(contains('EvidenceClassification')));
        expect(source, isNot(contains('ProofThreshold')));
      }
    });

    test('no transcript/body/private text in analytics', () {
      final source = File(
        'lib/features/low_friction_return/low_friction_return_analytics.dart',
      ).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('transcript')));
      expect(source, isNot(contains('entry_id')));
      expect(source, isNot(contains('body')));
    });
  });

  group('Low friction return placement', () {
    test('card sits under OpenCapturePromptChips on record screen', () {
      expectRecordScreenLayoutBefore(
        earlier: 'showOpenCapturePromptChips',
        later: 'showLowFrictionReturnCard',
      );
    });

    test('card sits above deeper archive proof cards', () {
      final source = readRecordScreenSource();
      final cardIndex = source.indexOf('LowFrictionReturnCard(');
      final freedomIndex = recordScreenShowCondition(
        source,
        'showCaptureFreedomLine',
      );
      final timelineIndex = source.indexOf(
        'if (!suppressLegacyEducationCardsForSpineOnRecord &&',
      );
      expect(cardIndex, greaterThan(0));
      expect(freedomIndex, greaterThan(cardIndex));
      expect(timelineIndex, greaterThan(cardIndex));
    });

    test('prompt selection sets selected prompt line only', () {
      final source = readRecordScreenSource();
      final snippet = source.substring(
        source.indexOf('LowFrictionReturnCard('),
        recordScreenShowCondition(source, 'showCaptureFreedomLine'),
      );
      expect(snippet, contains('_selectedPromptLine = prompt'));
      expect(snippet, isNot(contains('context.push')));
    });
  });
}
