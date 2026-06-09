import '../features/archive_beliefs/archive_belief_models.dart';
import '../features/archive_beliefs/belief_change_timeline.dart';
import '../features/insights/archive_insight.dart';
import '../features/insights/insight_evidence.dart';
import '../features/tomorrow_return/change_summary_model.dart';
import '../features/tomorrow_return/return_comparison_model.dart';
import '../features/tomorrow_return/return_streak_model.dart';
import '../features/tomorrow_return/weekly_pattern_recap_engine.dart';
import '../features/tomorrow_return/tomorrow_commitment_model.dart';
import '../features/activation/first_loop_activation_model.dart';
import '../features/activation/return_day_friction_model.dart';
import '../features/activation/first_three_journey_engine.dart';
import '../features/activation/first_three_journey_model.dart';
import '../features/archive_memory/archive_evolution_model.dart';
import '../features/archive_memory/archive_memory_summary_model.dart';
import '../features/archive_memory/memory_quality_model.dart';
import '../features/archive_compression/archive_compression_model.dart';
import '../features/first_session/first_session_pattern_model.dart';
import '../features/moments/key_moment_model.dart';
import '../features/pattern_map/pattern_map_model.dart';
import '../features/pattern_memory/habit_proof_model.dart';
import '../features/pattern_memory/pattern_memory_model.dart';
import '../features/pattern_memory/pattern_next_action_model.dart';
import '../features/pattern_memory/pattern_progress_model.dart';
import '../features/pattern_memory/pattern_share_recap_model.dart';
import '../features/pattern_memory/weekly_pattern_recap_model.dart' as wkrecap;
import '../features/tomorrow_return/active_pattern_thread_model.dart';
import '../features/tomorrow_return/tomorrow_return_loop_models.dart';
import '../features/tomorrow_return/return_capture_model.dart';
import '../features/objective/current_objective_model.dart';
import '../features/tomorrow_return/compelling_check_model.dart';
import '../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../features/tomorrow_return/watch_for_model.dart';
import '../product/consumer_ui_copy.dart';
import 'screenshot_mode.dart';

/// Polished sample content for marketing screenshots — never used in production.
abstract final class ScreenshotSampleData {
  ScreenshotSampleData._();

  static const heroStatement =
      'I feel responsible for keeping everything together.';

  static const heroWhy =
      'Your reflections often link pressure with carrying more than your share, '
      'and guilt when you slow down.';

  static const evidenceQuote1 = 'I keep saying I have to handle it.';
  static const evidenceQuote2 =
      'I avoid asking for help until I am exhausted.';
  static const evidenceQuote3 = 'I feel guilty when I slow down.';

  static ArchiveBeliefCardModel get heroBelief => ArchiveBeliefCardModel(
        id: 'screenshot-hero',
        statement: heroStatement,
        confidencePercent: 78,
        evidenceSummary: 'Based on 12 reflections.',
        whyExplanation: heroWhy,
        section: ArchiveBeliefSection.current,
        timeline: const [
          BeliefEvidenceQuote(periodLabel: 'Recent', quote: evidenceQuote1),
          BeliefEvidenceQuote(periodLabel: 'Earlier', quote: evidenceQuote2),
          BeliefEvidenceQuote(periodLabel: 'Earlier', quote: evidenceQuote3),
        ],
        conclusion:
            'This pattern shows up when work, family, and rest collide.',
      );

  static ArchiveBeliefsSnapshot get beliefsSnapshot => ArchiveBeliefsSnapshot(
        homeBeliefs: [heroBelief],
        current: [heroBelief],
        emerging: const [],
        changing: const [],
        hiddenPatterns: const [],
        stats: const ArchiveBeliefStats(
          beliefsIdentified: 4,
          strongestBelief: heroStatement,
          archiveAgeDays: 21,
          reflectionsAnalysed: 12,
          evidencePoints: 12,
        ),
      );

  static const returnLoopTodayNoticed =
      'You keep taking responsibility before asking for help.';

  static const List<String> returnLoopWatchChips = [
    'doing it alone',
    'saying yes too fast',
    'feeling responsible',
  ];

  static const returnLoopTomorrowPrompt =
      'Tomorrow, notice whether this shows up again.';

  static const commitmentSamplePrompt =
      'Notice whether you take responsibility before asking for help.';

  static const watchForPendingText =
      'whether you take responsibility before asking for help';

  static const watchForSpecificPrompt =
      'Tomorrow, notice if you say yes or carry something before checking what you need.';

  static const firstSessionWhyNoticed =
      'You mentioned pressure, responsibility, and saying yes before checking what you need.';

  static FirstSessionPattern get firstSessionPatternSample =>
      FirstSessionPattern(
        id: 'screenshot-first-pattern',
        createdAt: DateTime(2026, 5, 25, 10),
        title: 'Taking responsibility before asking for help',
        whyNoticed: firstSessionWhyNoticed,
        watchForText: watchForPendingText,
        chips: activePatternThreadChips,
        confidenceLabel: FirstSessionConfidenceLabel.early,
        sourceTextPreview:
            'I said yes too quickly again and felt responsible before asking for help.',
        matchReason:
            'Your words pointed toward pressure and guilt in this moment.',
        confidenceScore: 0.62,
        matchedPhrases: const ['pressure', 'saying yes', 'guilt'],
        alternativePatterns: const [],
        userCanCorrect: true,
        categoryId: 'responsibility',
      );

  static WatchForItem watchForPendingForToday(DateTime previewDay) {
    final target = TomorrowCommitment.dateOnly(previewDay);
    return WatchForItem(
      id: 'screenshot-watch-pending',
      createdAt: target.subtract(const Duration(days: 1, hours: 3)),
      targetDate: target,
      text: watchForSpecificPrompt,
      chips: returnLoopWatchChips,
      status: WatchForStatus.pending,
      result: WatchForResult.none,
      shortPrompt:
          'Notice if you take responsibility before asking for help.',
      specificPrompt: watchForSpecificPrompt,
      situationHint: 'especially when someone expects something from you',
      checkInQuestion: 'Did you ask for help, or carry it alone?',
      promptStrength: 'high',
    );
  }

  static String get watchForCompletedHeadline {
    final hint = ScreenshotMode.returnCaptureSelection?.comparisonHint ??
        ReturnCaptureComparisonHints.same;
    switch (hint) {
      case ReturnCaptureComparisonHints.lighter:
        return ConsumerUiCopy.watchForResultFeltLighterToday;
      case ReturnCaptureComparisonHints.heavier:
        return ConsumerUiCopy.watchForResultFeltHeavierToday;
      case ReturnCaptureComparisonHints.changed:
        return ConsumerUiCopy.watchForResultSomethingChangedToday;
      default:
        return ConsumerUiCopy.watchForResultShowedAgain;
    }
  }

  static String get watchForCompletedBody {
    final hint = ScreenshotMode.returnCaptureSelection?.comparisonHint ??
        ReturnCaptureComparisonHints.same;
    const watch =
        'taking responsibility before asking for help';
    switch (hint) {
      case ReturnCaptureComparisonHints.lighter:
        return 'Yesterday you were watching for $watch. Today you marked it as lighter.';
      case ReturnCaptureComparisonHints.heavier:
        return 'Yesterday you were watching for $watch. Today you marked it as heavier.';
      case ReturnCaptureComparisonHints.changed:
        return 'Yesterday you were watching for $watch. Today something felt different.';
      default:
        return 'Yesterday you were watching for $watch. Today it showed up again.';
    }
  }

  static const List<String> activePatternThreadChips = [
    'saying yes too fast',
    'carrying it alone',
    'asking late',
  ];

  static ActivePatternThread get activePatternThreadSample => ActivePatternThread(
        id: 'screenshot-active-thread',
        title: 'Taking responsibility before asking for help',
        createdAt: DateTime(2026, 5, 22, 9),
        updatedAt: DateTime(2026, 5, 25, 10, 15),
        watchForText: watchForPendingText,
        chips: activePatternThreadChips,
        status: ActivePatternThreadStatus.active,
        daysActive: 3,
        lastResult: WatchForResult.showedAgain,
        lastResultDate: DateTime(2026, 5, 25, 10, 15),
        recentMoments: const [
          'Said yes too quickly before asking for help.',
        ],
        recentResults: const [
          WatchForResult.showedAgain,
          WatchForResult.showedAgain,
        ],
        nextPrompt:
            'Today, notice whether you take responsibility before asking for help.',
      );

  static PatternMemory get patternMemorySample => PatternMemory(
        id: 'screenshot-pattern-memory',
        patternTitle: 'Taking responsibility before asking for help',
        createdAt: DateTime(2026, 5, 22, 9),
        updatedAt: DateTime(2026, 5, 25, 10, 15),
        checkInCount: 4,
        showedAgainCount: 2,
        lighterCount: 1,
        heavierCount: 1,
        changedCount: 0,
        lastResult: PatternMemoryResultHint.same,
        commonBeforeMoments: const [
          'when someone expected something',
          'before saying yes',
        ],
        helpedMoments: const [
          'paused before answering',
        ],
        harderMoments: const [],
        nextBestQuestion: 'What happens right before it shows up?',
        status: PatternMemoryStatus.active,
      );

  static PatternMap get patternMapSample => PatternMap(
        patternTitle: 'Taking responsibility before asking for help',
        seenCount: 8,
        lastSeenDate: DateTime(2026, 5, 25, 10, 15),
        usuallyStartsBefore: 'before saying yes',
        oftenFeelsLike: 'heavier',
        getsLighterWhen: 'pausing before answering',
        getsHeavierWhen: 'taking it on alone',
        nextCheck: 'What happens right before it shows up?',
        confidenceLabel: 'Based on 8 check-ins',
      );

  static ArchiveMemorySummary get archiveMemorySummarySample =>
      ArchiveMemorySummary(
        id: 'screenshot-archive-memory',
        patternTitle: 'Taking responsibility before asking for help',
        primaryMemoryLine:
            'You often take responsibility before asking for help.',
        startsBeforeLine: 'It often starts before: saying yes.',
        helpedLine: 'It has felt lighter when: pausing before answering.',
        basedOnMomentCount: 8,
        basedOnWeekCount: 3,
        firstSeenDate: DateTime(2026, 5, 4),
        lastSeenDate: DateTime(2026, 5, 25, 10, 15),
        clarityLabel: 'Clear pattern',
        nextCheck: 'Did you ask for help before saying yes?',
      );

  static MemoryQuality get memoryQualitySample => const MemoryQuality(
        level: MemoryQualityLevel.clearPattern,
        label: 'Clear pattern',
        helperText: 'This pattern is clear enough to check tomorrow.',
        momentCount: 8,
        checkInCount: 8,
        weekCount: 3,
        hasChangedRecently: false,
      );

  static ArchiveEvolutionTimeline get archiveEvolutionTimelineSample =>
      ArchiveEvolutionTimeline(
        patternTitle: 'Taking responsibility before asking for help',
        firstSeenDate: DateTime(2026, 5, 4),
        lastSeenDate: DateTime(2026, 5, 25, 10, 15),
        eventCount: 4,
        nextCheck: 'Did you ask for help before saying yes?',
        events: [
          ArchiveEvolutionEvent(
            id: 'screenshot-evolution-1',
            date: DateTime(2026, 5, 4, 9),
            type: ArchiveEvolutionEventType.firstSeen,
            title: 'First seen',
            body: 'You first recorded this pattern.',
            patternTitle: 'Taking responsibility before asking for help',
            momentId: 'screenshot-moment-week',
          ),
          ArchiveEvolutionEvent(
            id: 'screenshot-evolution-2',
            date: DateTime(2026, 5, 18, 14),
            type: ArchiveEvolutionEventType.showedAgain,
            title: 'Showed up again',
            body: 'It showed up after a work message.',
            patternTitle: 'Taking responsibility before asking for help',
            momentId: 'screenshot-moment-today',
          ),
          ArchiveEvolutionEvent(
            id: 'screenshot-evolution-3',
            date: DateTime(2026, 5, 22, 18),
            type: ArchiveEvolutionEventType.feltLighter,
            title: 'Felt lighter',
            body: 'It felt lighter after you paused.',
            patternTitle: 'Taking responsibility before asking for help',
            momentId: 'screenshot-moment-yesterday',
          ),
          ArchiveEvolutionEvent(
            id: 'screenshot-evolution-4',
            date: DateTime(2026, 5, 25, 10, 15),
            type: ArchiveEvolutionEventType.checkChosen,
            title: 'Check chosen',
            body: 'You chose what to check tomorrow.',
            patternTitle: 'Taking responsibility before asking for help',
            nextCheck: 'Did you ask for help before saying yes?',
          ),
        ],
      );

  static PatternProgressMoment get patternProgressSample =>
      PatternProgressMoment(
        id: 'screenshot-pattern-progress',
        memoryId: 'screenshot-pattern-memory',
        createdAt: DateTime(2026, 5, 25, 10, 15),
        type: PatternProgressType.stillRepeating,
        headline: 'This pattern is still showing up.',
        body: 'You have caught it 4 times. '
            'The useful part is that you are noticing the moment.',
        beforeLine: 'It often starts around: before saying yes',
        nextLine: 'Next, watch what happens right before it starts.',
        checkInCount: 4,
        shouldShow: true,
      );

  static PatternNextAction get patternNextActionSample => PatternNextAction(
        id: 'na_screenshot-pattern-memory_4_repeatCheck',
        memoryId: 'screenshot-pattern-memory',
        createdAt: DateTime(2026, 5, 25, 10, 15),
        type: PatternNextActionType.repeatCheck,
        title: 'Check what happens before it starts',
        body: 'You have caught this pattern more than once. '
            'Tomorrow, look at the moment right before it shows up.',
        question: 'What happens right before it shows up?',
        ctaLabel: 'Use this check',
        sourceProgressType: 'stillRepeating',
        sourceStatus: 'active',
      );

  static HabitProofMoment get habitProofSample => HabitProofMoment(
        id: 'hp_screenshot-pattern-memory_4_progressFound',
        memoryId: 'screenshot-pattern-memory',
        createdAt: DateTime(2026, 5, 25, 10, 15),
        type: HabitProofType.progressFound,
        headline: 'Now there is something to compare.',
        body: 'You can see whether this pattern is repeating, '
            'getting lighter, getting heavier, or changing.',
        proofLine: 'This pattern is still showing up.',
        nextLine: 'What happens right before it shows up?',
        checkInCount: 4,
        shouldShow: true,
      );

  static wkrecap.WeeklyPatternRecap get weeklyPatternRecapSample =>
      wkrecap.WeeklyPatternRecap(
        id: 'wr_screenshot-pattern-memory_20260525_repeated',
        memoryId: 'screenshot-pattern-memory',
        createdAt: DateTime(2026, 5, 25, 10, 15),
        weekStart: DateTime(2026, 5, 25),
        weekEnd: DateTime(2026, 5, 31),
        type: wkrecap.WeeklyPatternRecapType.repeated,
        patternTitle: 'saying yes when you mean no',
        headline: 'This pattern kept showing up this week.',
        body: 'You checked it 4 times and caught it more than once.',
        usefulLine: 'It often starts around: before saying yes',
        nextQuestion: 'What happens right before it starts?',
        checkInCount: 4,
        shouldShow: true,
      );

  static const String firstLoopPatternTitle = 'saying yes before checking in';
  static const String firstLoopTomorrowQuestion =
      'What happens right before you say yes?';

  /// First-loop activation state for a given screenshot stage:
  /// `start`, `saved`, `choosing`, or `ready`.
  static FirstLoopActivationState firstLoopStateFor(String stage) {
    final opened = DateTime(2026, 5, 25, 9, 0);
    switch (stage) {
      case 'saved':
        return FirstLoopActivationState(
          stage: FirstLoopActivationStage.firstMomentSaved,
          openedAt: opened,
          firstRecordingStartedAt: opened.add(const Duration(seconds: 8)),
          firstMomentSavedAt: opened.add(const Duration(seconds: 24)),
        );
      case 'choosing':
        return FirstLoopActivationState(
          stage: FirstLoopActivationStage.firstPatternShown,
          openedAt: opened,
          firstRecordingStartedAt: opened.add(const Duration(seconds: 8)),
          firstMomentSavedAt: opened.add(const Duration(seconds: 24)),
          firstPatternShownAt: opened.add(const Duration(seconds: 27)),
          firstPatternTitle: firstLoopPatternTitle,
        );
      case 'ready':
        return FirstLoopActivationState(
          stage: FirstLoopActivationStage.loopReady,
          openedAt: opened,
          firstRecordingStartedAt: opened.add(const Duration(seconds: 8)),
          firstMomentSavedAt: opened.add(const Duration(seconds: 24)),
          firstPatternShownAt: opened.add(const Duration(seconds: 27)),
          tomorrowCheckChosenAt: opened.add(const Duration(seconds: 40)),
          completedAt: opened.add(const Duration(seconds: 42)),
          firstPatternTitle: firstLoopPatternTitle,
          tomorrowQuestion: firstLoopTomorrowQuestion,
        );
      case 'start':
      default:
        return FirstLoopActivationState(
          stage: FirstLoopActivationStage.openedRecord,
          openedAt: opened,
        );
    }
  }

  /// Return-day friction state for a given screenshot stage:
  /// `due`, `answered`, or `closed`.
  static ReturnDayFrictionState returnDayStateFor(String stage) {
    const checkInId = 'screenshot-check-in-due';
    final shown = DateTime(2026, 5, 26, 9, 0);
    switch (stage) {
      case 'answered':
        return ReturnDayFrictionState(
          checkInId: checkInId,
          stage: ReturnDayFrictionStage.answerSelected,
          dueShownAt: shown,
          answerSelectedAt: shown.add(const Duration(seconds: 4)),
          selectedAnswer: 'showed_up_again',
        );
      case 'closed':
        return ReturnDayFrictionState(
          checkInId: checkInId,
          stage: ReturnDayFrictionStage.loopClosed,
          dueShownAt: shown,
          answerSelectedAt: shown.add(const Duration(seconds: 4)),
          recordingStartedAt: shown.add(const Duration(seconds: 6)),
          momentSavedAt: shown.add(const Duration(seconds: 18)),
          loopClosedAt: shown.add(const Duration(seconds: 20)),
          selectedAnswer: 'showed_up_again',
        );
      case 'due':
      default:
        return ReturnDayFrictionState(
          checkInId: checkInId,
          stage: ReturnDayFrictionStage.dueShown,
          dueShownAt: shown,
        );
    }
  }

  static PatternShareRecap get patternShareRecapSample {
    const title = 'This week\u2019s pattern';
    const body = 'This pattern kept showing up this week.';
    const lines = <String>[
      'You checked it 4 times and caught it more than once.',
      'It often starts around: before saying yes',
      'Next check: What happens right before it starts?',
    ];
    final plainText = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln(body)
      ..writeln();
    for (final line in lines) {
      plainText.writeln('- $line');
    }
    plainText
      ..writeln()
      ..write('Made with ArchiveMe');
    return PatternShareRecap(
      id: 'share_weekly_screenshot',
      createdAt: DateTime(2026, 5, 25, 10, 15),
      type: PatternShareRecapType.weekly,
      title: title,
      body: body,
      lines: lines,
      nextQuestion: 'What happens right before it starts?',
      plainText: plainText.toString(),
    );
  }

  static WatchForItem get watchForCompletedSample {
    final hint = ScreenshotMode.returnCaptureSelection?.comparisonHint ??
        ReturnCaptureComparisonHints.same;
    final result = hint == ReturnCaptureComparisonHints.lighter ||
            hint == ReturnCaptureComparisonHints.changed
        ? WatchForResult.changedShape
        : WatchForResult.showedAgain;
    return WatchForItem(
      id: 'screenshot-watch-completed',
      createdAt: DateTime(2026, 5, 24, 9),
      targetDate: DateTime(2026, 5, 25),
      text: watchForSpecificPrompt,
      chips: returnLoopWatchChips,
      status: WatchForStatus.checked,
      result: result,
      completedAt: DateTime(2026, 5, 25, 10, 15),
      specificPrompt: watchForSpecificPrompt,
      shortPrompt:
          'Notice if you take responsibility before asking for help.',
      comparisonHint: hint,
    );
  }

  /// Active commitment: committed yesterday, target is [previewDay].
  static TomorrowCommitment tomorrowCommitmentForPreview(DateTime previewDay) {
    final target = TomorrowCommitment.dateOnly(previewDay);
    return TomorrowCommitment(
      committedAt: target.subtract(const Duration(days: 1, hours: 2)),
      targetDate: target,
      promptText: commitmentSamplePrompt,
      watchForChips: returnLoopWatchChips,
    );
  }

  static TomorrowCommitment get tomorrowCommitmentActive =>
      tomorrowCommitmentForPreview(DateTime(2026, 5, 25));

  static const returnComparisonSampleChips = [
    'showed up again',
    'saying yes too fast',
    'ask for help sooner',
  ];

  static ReturnStreak get returnStreakSample {
    final today = DateTime(2026, 5, 25);
    final dates = [
      today.subtract(const Duration(days: 2)),
      today.subtract(const Duration(days: 1)),
      today,
    ];
    return ReturnStreak(
      currentStreakDays: 3,
      longestStreakDays: 3,
      lastCompletedDate: today,
      completedDates: dates,
      headline: ConsumerUiCopy.returnStreakHeadline,
      body: ConsumerUiCopy.returnStreakBody(3),
    );
  }

  static ChangeSummary get changeSummarySample => ChangeSummary(
        title: ConsumerUiCopy.changeSummaryTitleSteady,
        summary:
            'Taking responsibility too quickly showed up again today. '
            'It looks steady, not resolved yet.',
        status: ChangeSummaryStatus.steady,
        chips: const [
          'showed up again',
          'same pressure',
          'watch tomorrow',
        ],
        createdAt: DateTime(2026, 5, 25, 11),
      );

  static WeeklyPatternRecap get weeklyRecapSample => WeeklyPatternRecap(
        title: ConsumerUiCopy.weeklyRecapTitle,
        body:
            'Responsibility showed up more than once this week, especially around '
            'saying yes too quickly.',
        chips: const [
          'showed up again',
          'saying yes too fast',
          'feeling responsible',
        ],
      );

  static ReturnComparison get returnComparisonSample => ReturnComparison(
        yesterdayWatchFor:
            'taking responsibility before asking for help',
        todayReflectionSummary:
            'Saying yes too quickly again before asking for help.',
        comparisonStatus: ReturnComparisonStatus.repeated,
        headline: ConsumerUiCopy.returnComparisonHeadlineRepeated,
        body:
            'Yesterday you were watching for taking responsibility before asking for help. '
            "Today's reflection mentioned saying yes too quickly again.",
        chips: returnComparisonSampleChips,
        createdAt: DateTime(2026, 5, 25, 10, 30),
      );

  static TomorrowReturnLoop get tomorrowReturnLoop => TomorrowReturnLoop(
        noticedToday: returnLoopTodayNoticed,
        comeBackTomorrow:
            'After another reflection tomorrow, ArchiveMe can compare '
            'today with what you add next.',
        watchForNextTime:
            'Whether responsibility shows up before you ask for help.',
        generatedAt: DateTime(2026, 5, 12, 18, 30),
        watchForChips: returnLoopWatchChips,
        tomorrowPrompt: returnLoopTomorrowPrompt,
      );

  static List<BeliefChangeTimelineItem> get changingStories => [
        BeliefChangeTimelineItem(
          kind: BeliefChangeKind.shifting,
          statement: 'Carrying everything alone',
          detail:
              'You are starting to notice the cost of carrying everything alone.',
          sortOrder: 0,
        ),
      ];

  static ArchiveInsightsSnapshot get insightsSnapshot {
    final blindSpot = ArchiveInsight(
      id: 'screenshot-noticing',
      type: ArchiveInsightType.blindSpot,
      title: 'Worth noticing',
      summary: 'You rarely mention what support you need.',
      confidence: 72,
      evidenceCount: 8,
      supportingEvidence: [
        InsightEvidenceLine(
          entryId: 'b1',
          quote: evidenceQuote2,
          recordedAt: DateTime(2025, 5, 11),
        ),
      ],
      createdAt: DateTime(2025, 5, 11),
      archiveConclusion: 'Support language is scarce across recent reflections.',
    );

    final strongest = ArchiveInsight(
      id: 'screenshot-strongest',
      type: ArchiveInsightType.belief,
      title: heroStatement,
      summary: heroWhy,
      confidence: 78,
      evidenceCount: 12,
      supportingEvidence: [
        InsightEvidenceLine(
          entryId: 's1',
          quote: evidenceQuote1,
          recordedAt: DateTime(2025, 5, 12),
        ),
        InsightEvidenceLine(
          entryId: 's2',
          quote: evidenceQuote2,
          recordedAt: DateTime(2025, 5, 10),
        ),
        InsightEvidenceLine(
          entryId: 's3',
          quote: evidenceQuote3,
          recordedAt: DateTime(2025, 5, 8),
        ),
      ],
      createdAt: DateTime(2025, 5, 12),
      archiveConclusion: heroWhy,
    );

    return ArchiveInsightsSnapshot(
      strongestBelief: strongest,
      contradictions: const [],
      evolution: const [],
      blindSpots: [blindSpot],
      predictions: const [],
      allInsights: [strongest, blindSpot],
    );
  }

  static TomorrowCheckIn get tomorrowCheckInDueSample {
    final selectedId = ScreenshotMode.screenshotCheckInSelectedOptionId;
    final today = DateTime.now();
    return TomorrowCheckIn(
      id: 'screenshot-check-in-due',
      createdAt: today.subtract(const Duration(hours: 14)),
      targetDate: tomorrowCheckInDateKey(today),
      patternTitle: 'Taking responsibility before asking for help',
      prompt: 'Tomorrow, check whether this pattern shows up again.',
      question: 'Did you ask for help, or carry it alone?',
      options: kDefaultTomorrowCheckInOptions,
      selectedOptionId: selectedId,
      sourceWatchForId: 'screenshot-watch-pending',
    );
  }

  static TomorrowCheckIn get tomorrowCheckInSetForTomorrowSample {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return TomorrowCheckIn(
      id: 'screenshot-check-in-set',
      createdAt: DateTime.now(),
      targetDate: tomorrowCheckInDateKey(tomorrow),
      patternTitle: 'Taking responsibility before asking for help',
      prompt: 'Tomorrow, check whether this pattern shows up again.',
      question: 'Did you ask for help, or carry it alone?',
      options: kDefaultTomorrowCheckInOptions,
      sourceWatchForId: 'screenshot-watch-set',
    );
  }

  /// Sharpened tomorrow check for compelling-check screenshots.
  static const CompellingCheckQuestion compellingCheckSample =
      CompellingCheckQuestion(
    type: CompellingCheckType.beforeMoment,
    question: 'Did you say yes before checking what you needed?',
    whyThisCheck:
        'This is useful because it catches the moment before the pattern starts.',
    exampleAnswer: 'I noticed it before I said yes.',
    sharpnessLabel: CompellingCheckSharpness.direct,
  );

  static const CurrentObjective objectiveDueCheckSample = CurrentObjective(
    type: CurrentObjectiveType.answerTodayCheck,
    title: 'Today\u2019s check',
    body: 'Answer the check you chose yesterday.',
    checkQuestion: 'Did you say yes before checking what you needed?',
    patternTitle: 'Taking responsibility before asking for help',
    primaryCtaLabel: 'Answer check',
    route: '/record',
  );

  static const CurrentObjective objectiveFirstMomentSample = CurrentObjective(
    type: CurrentObjectiveType.recordFirstMoment,
    title: 'Start with one moment',
    body: 'Record one moment to start finding what repeats.',
    primaryCtaLabel: 'Record one moment',
    route: '/record',
  );

  static const CurrentObjective objectiveNextReadySample = CurrentObjective(
    type: CurrentObjectiveType.doneForToday,
    title: 'Next check ready',
    body: 'Come back tomorrow to answer it.',
    checkQuestion: 'Did you say yes before checking what you needed?',
    patternTitle: 'Taking responsibility before asking for help',
    primaryCtaLabel: 'Done',
    route: '/record',
  );

  /// A loop closed today, used to preview the "Next useful check" card.
  /// Three sample days for the Key Moments timeline screenshot.
  static List<KeyMoment> get keyMomentsSample => [
        KeyMoment(
          id: 'screenshot-moment-today',
          date: DateTime(2026, 5, 26, 9, 12),
          title: 'A pattern showed up again',
          originalText:
              'I said yes before checking what I needed, and it felt heavier '
              'after.',
          shortSummary: 'I said yes before checking what I needed.',
          patternTitle: 'Taking on too much before checking in',
          resultHint: 'heavier',
          nextCheck: 'What happened right before you said yes?',
          tags: const ['pressure', 'heavier'],
          source: KeyMomentSource.checkIn,
        ),
        KeyMoment(
          id: 'screenshot-moment-yesterday',
          date: DateTime(2026, 5, 25, 18, 30),
          title: 'Something felt lighter',
          originalText:
              'It felt lighter after I paused before replying to the message.',
          shortSummary: 'It felt lighter after I paused before replying.',
          patternTitle: 'Pausing before replying',
          resultHint: 'lighter',
          nextCheck: 'What helped make it lighter?',
          tags: const ['relationship', 'lighter', 'helped'],
          source: KeyMomentSource.checkIn,
        ),
        KeyMoment(
          id: 'screenshot-moment-week',
          date: DateTime(2026, 5, 22, 8, 5),
          title: 'Something changed',
          originalText:
              'I waited before answering and the worry did not take over '
              'this time.',
          shortSummary: 'I waited before answering this time.',
          patternTitle: 'Waiting before answering',
          resultHint: 'changed',
          nextCheck: 'What was different today?',
          tags: const ['worry', 'changed'],
          source: KeyMomentSource.reflection,
        ),
      ];

  /// Key moments spanning today, this week, and older for archive clean view.
  static List<KeyMoment> get archiveCleanKeyMomentsSample => [
        ...keyMomentsSample,
        KeyMoment(
          id: 'screenshot-moment-older',
          date: DateTime(2026, 5, 10, 10, 0),
          title: 'An earlier moment',
          originalText:
              'The pressure showed up before a busy week and I noticed it.',
          shortSummary: 'Pressure showed up before a busy week.',
          patternTitle: 'Pressure before busy weeks',
          resultHint: 'same',
          tags: const ['pressure', 'work'],
          source: KeyMomentSource.reflection,
        ),
      ];

  /// Fixed preview day for archive clean screenshots.
  static DateTime get archiveCleanPreviewDay => DateTime(2026, 5, 26, 12);

  /// Fixed preview day for archive range review screenshots.
  static DateTime get archiveReviewPreviewDay => DateTime(2026, 6, 6, 12);

  /// Six moments this week for archive range review screenshots.
  static List<KeyMoment> get archiveReviewMomentsSample => [
        KeyMoment(
          id: 'review-m1',
          date: DateTime(2026, 6, 6, 9),
          title: 'Said yes again',
          originalText: 'I said yes before checking what I needed.',
          shortSummary: 'Said yes before checking what I needed.',
          patternTitle: 'Taking on too much before checking in',
          resultHint: 'showed_up_again',
          tags: const ['pressure'],
          source: KeyMomentSource.checkIn,
        ),
        KeyMoment(
          id: 'review-m2',
          date: DateTime(2026, 6, 5, 18),
          title: 'Felt lighter after pausing',
          originalText: 'It felt lighter after I paused before replying.',
          shortSummary: 'It felt lighter after I paused before replying.',
          patternTitle: 'Taking on too much before checking in',
          resultHint: 'lighter',
          tags: const ['lighter', 'helped'],
          source: KeyMomentSource.checkIn,
        ),
        KeyMoment(
          id: 'review-m3',
          date: DateTime(2026, 6, 4, 12),
          title: 'Showed up again',
          originalText: 'The same pressure showed up before I agreed.',
          shortSummary: 'The same pressure showed up before I agreed.',
          patternTitle: 'Taking on too much before checking in',
          resultHint: 'same',
          source: KeyMomentSource.reflection,
        ),
        KeyMoment(
          id: 'review-m4',
          date: DateTime(2026, 6, 3, 8),
          title: 'Lighter after a walk',
          originalText: 'It felt lighter after a short walk.',
          shortSummary: 'It felt lighter after a short walk.',
          patternTitle: 'Taking on too much before checking in',
          resultHint: 'lighter',
          tags: const ['lighter'],
          source: KeyMomentSource.reflection,
        ),
        KeyMoment(
          id: 'review-m5',
          date: DateTime(2026, 6, 2, 19),
          title: 'Same pattern',
          originalText: 'I took it on again without checking first.',
          shortSummary: 'I took it on again without checking first.',
          patternTitle: 'Taking on too much before checking in',
          resultHint: 'showed_up_again',
          source: KeyMomentSource.reflection,
        ),
        KeyMoment(
          id: 'review-m6',
          date: DateTime(2026, 6, 1, 10),
          title: 'Another lighter moment',
          originalText: 'It felt lighter when I asked for more time.',
          shortSummary: 'It felt lighter when I asked for more time.',
          patternTitle: 'Taking on too much before checking in',
          resultHint: 'lighter',
          tags: const ['lighter', 'helped'],
          source: KeyMomentSource.reflection,
        ),
      ];

  /// A hard, self-blaming reflection used for the kinder-angle screenshot.
  static const String selfBlameReflection =
      'I said yes again and then felt stupid for not asking for help. '
      'It felt like my fault.';

  static TomorrowCheckIn get tomorrowCheckInCompletedSample => TomorrowCheckIn(
        id: 'screenshot-check-in-completed',
        createdAt: DateTime(2026, 5, 25, 18),
        targetDate: tomorrowCheckInDateKey(DateTime(2026, 5, 26, 9)),
        patternTitle: 'Taking responsibility before asking for help',
        prompt: 'Tomorrow, check whether this pattern shows up again.',
        question: 'Did you ask for help, or carry it alone?',
        options: kDefaultTomorrowCheckInOptions,
        selectedOptionId: 'showed_up_again',
        completedAt: DateTime(2026, 5, 26, 9, 12),
        sourceWatchForId: 'screenshot-watch-pending',
      );

  static FirstThreeJourneyModel firstThreeJourneyForCount(int count) {
    return const FirstThreeJourneyEngine().build(
      reflectionCount: count,
      activeThread: count >= 3 ? activePatternThreadSample : null,
      latestComparison: count >= 3 ? returnComparisonSample : null,
    );
  }

  /// Five similar moments across two weeks for archive compression screenshots.
  static List<KeyMoment> get archiveCompressionMomentsSample => [
        KeyMoment(
          id: 'compression-m1',
          date: DateTime(2026, 5, 12, 9, 0),
          title: 'Said yes before checking in',
          originalText: 'I said yes before checking what I needed at work.',
          shortSummary: 'Said yes before checking what I needed.',
          patternTitle: 'Taking responsibility before asking for help',
          resultHint: 'heavier',
          tags: const ['pressure', 'work'],
          source: KeyMomentSource.reflection,
        ),
        KeyMoment(
          id: 'compression-m2',
          date: DateTime(2026, 5, 15, 14, 30),
          title: 'Carried it alone again',
          originalText: 'I carried it alone again instead of asking for help.',
          shortSummary: 'Carried it alone again.',
          patternTitle: 'Taking responsibility before asking for help',
          resultHint: 'same',
          tags: const ['pressure', 'work'],
          source: KeyMomentSource.checkIn,
        ),
        KeyMoment(
          id: 'compression-m3',
          date: DateTime(2026, 5, 18, 8, 15),
          title: 'Paused before replying',
          originalText: 'It felt lighter after I paused before replying.',
          shortSummary: 'Paused before replying and it felt lighter.',
          patternTitle: 'Taking responsibility before asking for help',
          resultHint: 'lighter',
          tags: const ['pressure', 'work', 'helped'],
          source: KeyMomentSource.reflection,
        ),
        KeyMoment(
          id: 'compression-m4',
          date: DateTime(2026, 5, 22, 17, 0),
          title: 'Pressure before a message',
          originalText: 'The pressure showed up before I opened the message.',
          shortSummary: 'Pressure showed up before a message.',
          patternTitle: 'Taking responsibility before asking for help',
          resultHint: 'heavier',
          tags: const ['pressure', 'work'],
          source: KeyMomentSource.reflection,
        ),
        KeyMoment(
          id: 'compression-m5',
          date: DateTime(2026, 5, 26, 9, 12),
          title: 'Pattern showed up again',
          originalText: 'I said yes before checking what I needed again today.',
          shortSummary: 'Said yes before checking what I needed.',
          patternTitle: 'Taking responsibility before asking for help',
          resultHint: 'same',
          tags: const ['pressure', 'work', 'helped'],
          source: KeyMomentSource.checkIn,
        ),
      ];

  static ArchiveMomentGroup get archiveCompressionGroupSample =>
      ArchiveMomentGroup(
        id: 'grp_pattern_compression_sample',
        title: 'Taking responsibility before asking for help',
        momentIds: archiveCompressionMomentsSample.map((m) => m.id).toList(),
        patternTitle: 'Taking responsibility before asking for help',
        tags: const ['pressure', 'work', 'helped'],
        firstDate: DateTime(2026, 5, 12),
        lastDate: DateTime(2026, 5, 26),
        count: 5,
        suggestedAction: ArchiveCompressionSuggestedAction.keepTogether,
      );
}
