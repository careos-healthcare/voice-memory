import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/what_to_notice_next/what_to_notice_next_analytics.dart';
import 'package:archiveme_mobile/features/what_to_notice_next/what_to_notice_next_copy.dart';
import 'package:archiveme_mobile/features/what_to_notice_next/what_to_notice_next_engine.dart';
import 'package:archiveme_mobile/features/what_to_notice_next/what_to_notice_next_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/record/what_to_notice_next_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? _now,
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
    );

List<JournalEntry> _threeRelatedEntries() => [
  _entry('1', _strongRepeat, createdAt: _now.subtract(const Duration(days: 2))),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: _now.subtract(const Duration(days: 1)),
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: _now,
  ),
];

WhatToNoticeNextResult _buildResult(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = false,
}) => WhatToNoticeNextEngine.build(
  entries: entries,
  beliefSurfaceVisible: beliefSurfaceVisible,
  source: 'test',
  now: _now,
);

bool _shouldShow({
  required WhatToNoticeNextResult? result,
  int entryCount = 1,
  bool isReady = true,
  bool isRecording = false,
  bool isPostSave = false,
  bool isDegradedTranscriptState = false,
  bool firstProofPayoffVisible = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool lowFrictionReturnVisible = false,
  bool betaTodaySummaryVisible = false,
  bool openCapturePromptChipsVisible = false,
}) => WhatToNoticeNextEngine.shouldShow(
  result: result,
  isReady: isReady,
  isRecording: isRecording,
  isPostSave: isPostSave,
  isDegradedTranscriptState: isDegradedTranscriptState,
  firstProofPayoffVisible: firstProofPayoffVisible,
  whatChangedQuestionActive: whatChangedQuestionActive,
  patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
  entryCount: entryCount,
  lowFrictionReturnVisible: lowFrictionReturnVisible,
  betaTodaySummaryVisible: betaTodaySummaryVisible,
  openCapturePromptChipsVisible: openCapturePromptChipsVisible,
);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  String? selectedPrompt;

  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    WhatToNoticeNextAnalytics.resetForTest();
    WhatToNoticeNextAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    selectedPrompt = null;
  });

  tearDown(WhatToNoticeNextAnalytics.resetForTest);

  group('WhatToNoticeNextEngine', () {
    test('uses notice prompts with enough evidence', () {
      final result = _buildResult(_threeRelatedEntries());
      expect(result.usesFallbackPrompts, isFalse);
      for (final type in WhatToNoticeNextCopy.noticePromptTypes) {
        expect(
          result.prompts.map((prompt) => prompt.text),
          contains(WhatToNoticeNextCopy.promptTextFor(type)),
        );
      }
    });

    test('uses fallback prompts with little evidence', () {
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(result.usesFallbackPrompts, isTrue);
      for (final type in WhatToNoticeNextCopy.fallbackPromptTypes) {
        expect(
          result.prompts.map((prompt) => prompt.text),
          contains(WhatToNoticeNextCopy.promptTextFor(type)),
        );
      }
    });

    test('hidden when beta flag false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(_shouldShow(result: result), isFalse);
    });

    test('visible when beta flag true', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(_shouldShow(result: result), isTrue);
    });

    test('hidden with zero entries', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult(const []);
      expect(_shouldShow(result: result, entryCount: 0), isFalse);
    });

    test('hidden while recording', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(
        _shouldShow(result: result, isRecording: true),
        isFalse,
      );
    });

    test('hidden post-save', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(
        _shouldShow(result: result, isPostSave: true),
        isFalse,
      );
    });

    test('hidden degraded', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(
        _shouldShow(
          result: result,
          isDegradedTranscriptState: true,
        ),
        isFalse,
      );
    });

    test('hidden during FirstProofPayoff', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(
        _shouldShow(
          result: result,
          firstProofPayoffVisible: true,
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(
        _shouldShow(
          result: result,
          whatChangedQuestionActive: true,
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox active item', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(
        _shouldShow(
          result: result,
          patternReviewInboxHasActiveItems: true,
        ),
        isFalse,
      );
    });

    test('hidden when too many guidance cards compete', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      final result = _buildResult([_entry('1', _strongRepeat)]);
      expect(
        _shouldShow(
          result: result,
          lowFrictionReturnVisible: true,
          betaTodaySummaryVisible: true,
        ),
        isFalse,
      );
    });

    test('does not classify evidence', () {
      for (final path in [
        'lib/features/what_to_notice_next/what_to_notice_next_engine.dart',
        'lib/widgets/record/what_to_notice_next_card.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('ArchiveEvidenceQuality')));
        expect(source, isNot(contains('EvidenceClassification')));
      }
    });
  });

  group('WhatToNoticeNextCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      WhatToNoticeNextResult result, {
      bool withPromptSelection = true,
    }) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WhatToNoticeNextCard.test(
                result: result,
                onPromptSelected: withPromptSelection
                    ? (prompt) => selectedPrompt = prompt
                    : null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders What to notice next', (tester) async {
      await pumpCard(tester, _buildResult([_entry('1', _strongRepeat)]));
      expect(find.text(WhatToNoticeNextCopy.title), findsOneWidget);
    });

    testWidgets('renders You do not need to force an entry', (tester) async {
      await pumpCard(tester, _buildResult([_entry('1', _strongRepeat)]));
      expect(find.text(WhatToNoticeNextCopy.body), findsOneWidget);
    });

    testWidgets('renders all notice prompts', (tester) async {
      await pumpCard(tester, _buildResult(_threeRelatedEntries()));
      for (final type in WhatToNoticeNextCopy.noticePromptTypes) {
        expect(
          find.text(WhatToNoticeNextCopy.promptTextFor(type)),
          findsOneWidget,
        );
      }
    });

    testWidgets('renders fallback prompts when little evidence', (
      tester,
    ) async {
      await pumpCard(tester, _buildResult([_entry('1', _strongRepeat)]));
      for (final type in WhatToNoticeNextCopy.fallbackPromptTypes) {
        expect(
          find.text(WhatToNoticeNextCopy.promptTextFor(type)),
          findsOneWidget,
        );
      }
    });

    testWidgets('renders If nothing stands out, skip today.', (tester) async {
      await pumpCard(tester, _buildResult([_entry('1', _strongRepeat)]));
      expect(find.text(WhatToNoticeNextCopy.closingLine), findsOneWidget);
    });

    testWidgets('tapping prompt sets callback without routing', (tester) async {
      await pumpCard(tester, _buildResult([_entry('1', _strongRepeat)]));
      await tester.ensureVisible(
        find.text(
          WhatToNoticeNextCopy.promptTextFor(
            WhatToNoticeNextPromptType.whatHelped,
          ),
        ),
      );
      await tester.tap(
        find.text(
          WhatToNoticeNextCopy.promptTextFor(
            WhatToNoticeNextPromptType.whatHelped,
          ),
        ),
      );
      await tester.pump();

      expect(
        selectedPrompt,
        WhatToNoticeNextCopy.promptTextFor(
          WhatToNoticeNextPromptType.whatHelped,
        ),
      );
      expect(find.byType(Navigator), findsWidgets);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(tester, _buildResult(_threeRelatedEntries()));
      await tester.ensureVisible(
        find.text(
          WhatToNoticeNextCopy.promptTextFor(
            WhatToNoticeNextPromptType.didAnythingHelp,
          ),
        ),
      );
      await tester.tap(
        find.text(
          WhatToNoticeNextCopy.promptTextFor(
            WhatToNoticeNextPromptType.didAnythingHelp,
          ),
        ),
      );
      await tester.pump();

      final seen = analyticsEvents.firstWhere(
        (event) => event.event == WhatToNoticeNextAnalytics.seenEvent,
      );
      expect(
        seen.props.keys,
        containsAll([
          'source',
          'entry_count',
          'has_confirmed_repeat',
          'has_timeline',
        ]),
      );
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('body')));

      final tapped = analyticsEvents.firstWhere(
        (event) => event.event == WhatToNoticeNextAnalytics.promptTappedEvent,
      );
      expect(tapped.props['prompt_type'], 'did_anything_help');
    });
  });

  group('What to notice next copy guard', () {
    test('no daily pressure copy', () {
      final blob = WhatToNoticeNextCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('must record every day')));
      expect(blob, isNot(contains('journal every day')));
      expect(blob, contains('do not need to force an entry'));
    });

    test('no streak copy', () {
      final blob = WhatToNoticeNextCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('streak')));
      expect(blob, isNot(contains('day in a row')));
    });

    test('no therapy/medical copy', () {
      for (final line in WhatToNoticeNextCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });

    test('no transcript/body/private text in analytics', () {
      final source = File(
        'lib/features/what_to_notice_next/what_to_notice_next_analytics.dart',
      ).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('transcript')));
      expect(source, isNot(contains('entry_id')));
    });
  });

  group('What to notice next placement', () {
    test('card sits below beta today summary and above deeper proof cards', () {
      final source = readRecordScreenLibrarySource();
      final summaryIndex = source.indexOf(
        'if (ctx.showBetaTodaySummaryCard &&\n'
        '            ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&\n'
        '            !ctx.firstUseSimplifiedRecord) ...[',
      );
      final noticeIndex = source.indexOf(
        'if (ctx.showWhatToNoticeNextCard &&\n'
        '            !ctx.firstUseSimplifiedRecord &&\n'
        '            !ctx.recordReadySuppressStreakPressure) ...[',
      );
      final freedomIndex = source.indexOf(
        'if (ctx.showCaptureFreedomLine &&\n'
        '            !ctx.firstUseSimplifiedRecord &&\n'
        '            !ctx.showReturningWatchTargetFocusedUi) ...[',
      );
      expect(summaryIndex, greaterThan(0));
      expect(noticeIndex, greaterThan(summaryIndex));
      expect(freedomIndex, greaterThan(noticeIndex));
    });

    test('prompt selection sets selected prompt line only', () {
      final source = readRecordScreenLibrarySource();
      final snippet = source.substring(
        source.indexOf('WhatToNoticeNextCard('),
        source.indexOf(
          'if (ctx.showCaptureFreedomLine &&\n'
          '            !ctx.firstUseSimplifiedRecord &&\n'
          '            !ctx.showReturningWatchTargetFocusedUi) ...[',
        ),
      );
      expect(snippet, contains('_selectedPromptLine = prompt'));
      expect(snippet, isNot(contains('context.push')));
    });
  });
}