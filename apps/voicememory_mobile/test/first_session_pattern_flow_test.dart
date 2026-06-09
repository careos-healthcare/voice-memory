import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/activation/first_pattern_correction_store.dart';
import 'package:voicememory_mobile/features/first_session/first_session_coordinator.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:voicememory_mobile/features/first_session/pattern_correction_learning_coordinator.dart';
import 'package:voicememory_mobile/features/first_session/pattern_correction_learning_store.dart';
import 'package:voicememory_mobile/features/language/localized_copy.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_prompt_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/active_pattern_thread_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_store.dart';
import 'package:voicememory_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/return_comparison_card.dart';
import 'package:voicememory_mobile/widgets/patterns/return_streak_card.dart';
import 'package:voicememory_mobile/widgets/record/first_session_pattern_card.dart';
import 'package:voicememory_mobile/widgets/record/tomorrow_return_card.dart';

bool _visibleContainsBanned(String visible, String word) {
  if (word == 'archive') {
    return RegExp(r'\barchive\b(?!me)', caseSensitive: false).hasMatch(visible);
  }
  return visible.contains(word);
}

const _bannedVisible = <String>[
  'voicememory',
  'belief',
  'intelligence',
  'evidence',
  'signal',
  'prediction',
  'contradiction',
  'discovery',
  'engine',
  'analysis',
];

JournalEntry _entryWithText(String text) {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 5, 25),
    transcript: text,
    durationSeconds: 40,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: const [],
      exactLanguagePattern: text,
      concreteObservation: text,
      repeatedSignal: text,
    ),
  );
}

JournalEntry _responsibilityEntry() => _entryWithText(
      'I said yes too quickly and felt responsible before asking for help',
    );

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_first_session_journal_$stamp.json',
    prefsPath: '/tmp/vm_first_session_prefs_$stamp.json',
  );
}

void main() {
  test('tapping Use this tomorrow stores watch-for and creates active thread',
      () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final pattern = const FirstSessionPatternEngine().build(_responsibilityEntry());
    await FirstSessionCoordinator.acceptForTomorrow(pattern);

    final watchStore = WatchForStore(AppServices.instance.prefs);
    final threadStore = ActivePatternThreadStore(AppServices.instance.prefs);
    final expectedWatchFor =
        const WatchForPromptEngine().build(pattern: pattern);

    expect((await watchStore.readPending())?.text, expectedWatchFor.specificPrompt);
    expect((await threadStore.readCurrent())?.title, pattern.title);
    final checkIn = await TomorrowCheckInStore(AppServices.instance.prefs)
        .loadActive();
    expect(checkIn?.patternTitle, pattern.title);
    expect(checkIn?.question, isNotEmpty);
  });

  testWidgets('first-session card renders without banned words', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pattern = ScreenshotSampleData.firstSessionPatternSample;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(pattern: pattern),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(ConsumerUiCopy.firstSessionPatternHeadline),
      findsOneWidget,
    );
    expect(find.text(pattern.title), findsOneWidget);
    expect(find.text(ConsumerUiCopy.firstSessionUseTomorrowCta), findsOneWidget);
    expect(find.textContaining('ArchiveMe noticed'), findsOneWidget);

    final visible = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .join('\n')
        .toLowerCase();
    for (final word in _bannedVisible) {
      expect(
        _visibleContainsBanned(visible, word),
        isFalse,
        reason: 'found $word',
      );
    }
  });

  testWidgets('Show original reveals the preserved reflection text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const original = 'Dije que sí antes de preguntar qué necesitaba.';
    final pattern = ScreenshotSampleData.firstSessionPatternSample;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(
              pattern: pattern,
              languageCode: 'es',
              reflectionText: original,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(original), findsNothing);

    await tester.tap(find.text(localized('showOriginal', 'es')));
    await tester.pump();

    expect(find.text(original), findsOneWidget);
  });

  testWidgets('first-session card shows one feedback row and confirms a tap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pattern = ScreenshotSampleData.firstSessionPatternSample;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(pattern: pattern),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Was this useful?'), findsOneWidget);

    await tester.ensureVisible(find.text('More specific'));
    await tester.tap(find.text('More specific'));
    await tester.pumpAndSettle();

    expect(find.text('Got it.'), findsOneWidget);
  });

  testWidgets('weak input shows Early read and offers another moment',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var addAnother = false;
    final pattern = ScreenshotSampleData.firstSessionPatternSample;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(
              pattern: pattern,
              weakInput: true,
              onAddAnotherMoment: () => addAnother = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(ConsumerUiCopy.inputQualityEarlyReadLabel),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.firstPatternEarlyReadHint),
      findsOneWidget,
    );

    await tester.tap(find.text(ConsumerUiCopy.firstPatternAddAnotherMomentCta));
    await tester.pump();
    expect(addAnother, isTrue);
  });

  testWidgets('choosing compelling sharpness passes override question to accept',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? capturedQuestion = 'unset';
    final pattern = ScreenshotSampleData.firstSessionPatternSample;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(
              pattern: pattern,
              onAccept: (
                p, {
                correctionLearningId,
                reflectionText,
                sourceReflectionId,
                selectedVariantId,
                checkInQuestionOverride,
              }) async {
                capturedQuestion = checkInQuestionOverride;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(ConsumerUiCopy.firstSessionWatchTomorrowSection),
      findsOneWidget,
    );

    await tester.tap(find.text(ConsumerUiCopy.makeItSharperCta));
    await tester.pump();

    expect(
      find.text(ConsumerUiCopy.chooseTomorrowQuestionLabel),
      findsOneWidget,
    );

    await tester.tap(find.text('Direct'));
    await tester.pump();
    await tester.tap(find.text(ConsumerUiCopy.firstSessionUseTomorrowCta));
    await tester.pump();
    await tester.pump();

    expect(capturedQuestion, isNotNull);
    expect(capturedQuestion, isNot('unset'));
    expect(capturedQuestion!.trim(), isNotEmpty);
  });

  testWidgets('aggressive sharper defaults to Direct compelling check',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? capturedQuestion = 'unset';
    final pattern = ScreenshotSampleData.firstSessionPatternSample;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FirstSessionPatternCard(
              pattern: pattern,
              sharperIntensity: HookRescueIntensity.aggressive,
              onAccept: (
                p, {
                correctionLearningId,
                reflectionText,
                sourceReflectionId,
                selectedVariantId,
                checkInQuestionOverride,
              }) async {
                capturedQuestion = checkInQuestionOverride;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Direct'), findsOneWidget);

    await tester.tap(find.text(ConsumerUiCopy.firstSessionUseTomorrowCta));
    await tester.pump();
    await tester.pump();
    expect(capturedQuestion, isNotNull);
    expect(capturedQuestion!.trim(), isNotEmpty);
  });

  test('correction path can swap to fallback alternative', () {
    final engine = const FirstSessionPatternEngine();
    final pattern = engine.build(
      _entryWithText(
        'I feel anxious and exhausted, worried, cannot switch off, drained with no energy',
      ),
    );

    expect(pattern.userCanCorrect, isTrue);
    expect(pattern.alternativePatterns, isNotEmpty);

    final corrected = pattern.withAlternative(engine.fallbackAlternative());
    expect(corrected.title, 'Something worth watching');
    expect(corrected.watchForText, isNot(pattern.watchForText));
  });

  testWidgets('first-session post-save stack is minimal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                FirstSessionPatternCard(
                  pattern: ScreenshotSampleData.firstSessionPatternSample,
                ),
                TomorrowReturnCard(
                  loop: ScreenshotSampleData.tomorrowReturnLoop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FirstSessionPatternCard), findsOneWidget);
    expect(find.byType(TomorrowReturnCard), findsOneWidget);
    expect(find.byType(ReturnComparisonCard), findsNothing);
    expect(find.byType(ReturnStreakCard), findsNothing);
  });

  test('screenshot sample first session pattern exists', () {
    final sample = ScreenshotSampleData.firstSessionPatternSample;
    expect(sample.title, contains('Taking responsibility'));
    expect(sample.matchedPhrases, isNotEmpty);
    expect(sample.noticedBecauseLine, contains('ArchiveMe noticed'));
    expect(sample.chips, hasLength(3));
  });

  test('isFirstSession true for low count and no history', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    expect(await FirstSessionCoordinator.isFirstSession(reflectionCount: 1), isTrue);
  });

  test('correction is stored locally', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final pattern = const FirstSessionPatternEngine().build(_responsibilityEntry());
    final alt = pattern.withAlternative(
      const FirstSessionPatternEngine().fallbackAlternative(),
    );

    await ActivationTracker.trackFirstPatternCorrected(
      originalTitle: pattern.title,
      selectedTitle: alt.title,
      confidenceScore: pattern.confidenceScore,
    );

    final store = FirstPatternCorrectionStore(AppServices.instance.prefs);
    expect(await store.correctionCount(), 1);
  });

  test('correction learning stores and accept uses corrected watch-for', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final engine = const FirstSessionPatternEngine();
    final original = engine.build(_responsibilityEntry());
    final corrected = original.withAlternative(
      FirstSessionPatternAlternative(
        title: 'The same worry returning',
        whyNoticed: 'worry',
        watchForText: 'whether the same worry shows up again',
        chips: const ['same worry'],
        confidenceScore: 0.4,
        categoryId: 'worry',
      ),
    );

    final learning =
        await PatternCorrectionLearningCoordinator.recordFirstSessionCorrection(
      originalPattern: original,
      correctedPattern: corrected,
      reflectionText: _responsibilityEntry().transcript,
    );

    await FirstSessionCoordinator.acceptForTomorrow(
      corrected,
      correctionLearningId: learning.id,
      reflectionText: _responsibilityEntry().transcript,
    );

    final watchStore = WatchForStore(AppServices.instance.prefs);
    final pending = await watchStore.readPending();
    final expected = const WatchForPromptEngine().build(pattern: corrected);
    expect(pending?.text, expected.specificPrompt);
    expect(pending?.checkInQuestion, expected.checkInQuestion);
    expect(pending?.hasRichPrompt, isTrue);

    final learned = PatternCorrectionLearningStore(AppServices.instance.prefs);
    final item = (await learned.readAll()).first;
    expect(item.usedForNextPrompt, isTrue);
    expect(item.correctedTitle, 'The same worry returning');
  });

  test('checkInQuestionOverride changes stored check-in question', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final pattern = const FirstSessionPatternEngine().build(_responsibilityEntry());
    await FirstSessionCoordinator.acceptForTomorrow(
      pattern,
      checkInQuestionOverride: 'Did you say yes before checking what you needed?',
    );

    final checkIn =
        await TomorrowCheckInStore(AppServices.instance.prefs).loadActive();
    expect(
      checkIn?.question,
      'Did you say yes before checking what you needed?',
    );
  });

  test('selecting sharper variant changes pending watch-for prompt', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final pattern = const FirstSessionPatternEngine().build(_responsibilityEntry());
    await FirstSessionCoordinator.acceptForTomorrow(
      pattern,
      selectedVariantId: 'sharper',
    );

    final pending = await WatchForStore(AppServices.instance.prefs).readPending();
    expect(
      pending?.specificPrompt,
      'Tomorrow, notice if you carry something before asking for help.',
    );
    expect(pending?.checkInQuestion, 'Did you carry it alone again?');
  });

  test('accepting first pattern stores stronger watch-for prompt', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final pattern = const FirstSessionPatternEngine().build(_responsibilityEntry());
    await FirstSessionCoordinator.acceptForTomorrow(
      pattern,
      reflectionText: _responsibilityEntry().transcript,
    );

    final pending = await WatchForStore(AppServices.instance.prefs).readPending();
    expect(pending?.specificPrompt, contains('Tomorrow, notice'));
    expect(pending?.shortPrompt, contains('Notice if'));
    expect((pending?.situationHint ?? '').isNotEmpty, isTrue);
    expect(pending?.checkInQuestion, isNotEmpty);
  });
}
