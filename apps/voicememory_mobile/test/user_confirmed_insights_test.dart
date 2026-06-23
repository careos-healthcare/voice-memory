import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_copy.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_engine.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_store.dart';
import 'package:voicememory_mobile/features/then_now/then_now_copy.dart';
import 'package:voicememory_mobile/features/then_now/then_now_engine.dart';
import 'package:voicememory_mobile/features/then_now/then_now_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/then_vs_now_screen.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/insight_feedback_actions.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  "don't miss",
  'you must',
  'you always',
  'you never',
  'proves',
  'voice memory',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'pro is active',
  'ai learned',
  'model trained',
  'you are right',
  'you are wrong',
];

Reflection _reflection() => const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up in this moment.',
      repeatedSignal: '',
    );

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript: transcript ??
          'I felt pressure at work before saying yes again even when I was tired today.',
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: _reflection(),
    );

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
    expect(lower, isNot(contains('voicememory')));
  }
}

ThenNowResult _thenNowResult() => const ThenNowResult(
      hasCard: true,
      headline: ThenNowCopy.comparisonHeadline,
      thenLabel: ThenNowCopy.thenLabel,
      thenSummary: ThenNowCopy.thenMoreOften,
      nowLabel: ThenNowCopy.nowLabel,
      nowSummary: ThenNowCopy.nowShifting,
      evidenceCountLabel: '3 earlier · 4 newer · 7 saved moments',
      helperText: ThenNowCopy.helperText,
      cautionLabel: ThenNowCopy.cautionLabel,
      primaryCtaLabel: ThenNowCopy.saveAnotherMomentCta,
      primaryRoute: ThenNowCopy.recordRoute,
      secondaryCtaLabel: ThenNowCopy.reviewChangeCta,
      secondaryRoute: ThenNowCopy.route,
      reasonId: ThenNowReasonId.themeComparison,
      showOnArchiveHome: true,
    );

void main() {
  const engine = InsightFeedbackEngine();

  group('InsightFeedbackActions', () {
    testWidgets('feedback actions render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const InsightFeedbackActions.test(
            insightId: InsightFeedbackIds.thenVsNow,
            insightType: InsightFeedbackType.thenVsNow,
            sourceRoute: ThenNowCopy.route,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('insight_feedback_actions')), findsOneWidget);
      expect(find.text(InsightFeedbackCopy.prompt), findsOneWidget);
      expect(find.text(InsightFeedbackCopy.fits), findsOneWidget);
      expect(find.text(InsightFeedbackCopy.notQuite), findsOneWidget);
      expect(find.text(InsightFeedbackCopy.tooEarly), findsOneWidget);
      expect(find.text(InsightFeedbackCopy.saveAsWatchTheme), findsOneWidget);
    });
  });

  group('InsightFeedbackStore', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late InsightFeedbackStore store;
    late JournalStore journalStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('insight_feedback_test_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = InsightFeedbackStore(prefs);
      journalStore = await JournalStore.open('${tempDir.path}/journal.json');
      await InsightFeedbackStore.resetForTest();
    });

    tearDown(() async {
      await InsightFeedbackStore.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> saveChoice(InsightFeedbackChoice choice) async {
      await store.saveRecord(
        InsightFeedbackRecord(
          insightId: InsightFeedbackIds.thenVsNow,
          insightType: InsightFeedbackType.thenVsNow,
          choice: choice,
          createdAt: DateTime(2026, 6, 12),
          sourceRoute: ThenNowCopy.route,
        ),
      );
      final loaded = await store.loadAll();
      InsightFeedbackStore.seedForTest(loaded);
    }

    test('This fits persists locally', () async {
      await saveChoice(InsightFeedbackChoice.fits);
      final raw = await prefs.readJsonMap(InsightFeedbackStore.prefsKey);
      expect(raw, isNotNull);
      expect(raw!['records'], isA<List>());
      final records = raw['records'] as List;
      expect(records.last['choice'], 'fits');
    });

    test('Not quite persists locally', () async {
      await saveChoice(InsightFeedbackChoice.notQuite);
      final loaded = await store.loadAll();
      expect(loaded.last.choice, InsightFeedbackChoice.notQuite);
    });

    test('Too early to say persists locally', () async {
      await saveChoice(InsightFeedbackChoice.tooEarly);
      final loaded = await store.loadAll();
      expect(loaded.last.choice, InsightFeedbackChoice.tooEarly);
    });

    test('latest feedback is returned correctly', () async {
      await saveChoice(InsightFeedbackChoice.fits);
      await store.saveRecord(
        InsightFeedbackRecord(
          insightId: InsightFeedbackIds.thenVsNow,
          insightType: InsightFeedbackType.thenVsNow,
          choice: InsightFeedbackChoice.notQuite,
          createdAt: DateTime(2026, 6, 13),
          sourceRoute: ThenNowCopy.route,
        ),
      );
      final loaded = await store.loadAll();
      InsightFeedbackStore.seedForTest(loaded);
      expect(
        InsightFeedbackStore.latestFor(InsightFeedbackIds.thenVsNow)?.choice,
        InsightFeedbackChoice.notQuite,
      );
    });

    test('feedback counts are derived correctly', () async {
      await saveChoice(InsightFeedbackChoice.fits);
      await store.saveRecord(
        InsightFeedbackRecord(
          insightId: InsightFeedbackIds.archiveClarity,
          insightType: InsightFeedbackType.archiveClarity,
          choice: InsightFeedbackChoice.notQuite,
          createdAt: DateTime(2026, 6, 13),
          sourceRoute: '/archive-clarity-progress',
        ),
      );
      final loaded = await store.loadAll();
      InsightFeedbackStore.seedForTest(loaded);
      final summary = engine.summaryFor();
      expect(summary.fitsCount, 1);
      expect(summary.notQuiteCount, 1);
    });

    test('no raw transcript/journal text stored', () async {
      await journalStore.save(
        _entry('j1', transcript: 'Private journal name detail should never persist'),
      );
      await saveChoice(InsightFeedbackChoice.fits);
      final prefsRaw = await File('${tempDir.path}/prefs.json').readAsString();
      expect(prefsRaw, contains('archiveInsightFeedbackRecords'));
      expect(prefsRaw, isNot(contains('Private journal name detail should never persist')));
    });

    test('save-as-watch-theme stores safe local choice only', () async {
      await saveChoice(InsightFeedbackChoice.saveAsWatchTheme);
      final loaded = await store.loadAll();
      expect(loaded.last.choice, InsightFeedbackChoice.saveAsWatchTheme);
      expect(loaded.last.sourceRoute, ThenNowCopy.route);
      expect(loaded.last.insightId, InsightFeedbackIds.thenVsNow);
    });
  });

  group('InsightFeedbackEngine', () {
    setUp(InsightFeedbackStore.resetForTest);

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy = InsightFeedbackCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(InsightFeedbackCopy.allVisibleStrings);
    });
  });

  group('Then vs Now integration', () {
    testWidgets('Then vs Now screen shows feedback actions when card exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ThenVsNowScreen(initialResult: _thenNowResult()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('insight_feedback_actions')), findsOneWidget);
      expect(find.text(InsightFeedbackCopy.prompt), findsOneWidget);
    });
  });

  group('Support & Feedback', () {
    test('support screen mentions user-confirmed insights', () {
      final support =
          File('lib/screens/support_feedback_screen.dart').readAsStringSync();
      expect(support, contains('InsightFeedbackCopy.supportSectionTitle'));
      expect(support, contains('support_feedback_insight_feedback'));
    });
  });
}
