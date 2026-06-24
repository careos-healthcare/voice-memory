import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_copy.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_copy.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_engine.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_models.dart';
import 'package:voicememory_mobile/features/review_ritual/view_ritual_copy.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_copy.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'streak',
  'guilt',
  'coaching',
  'diary',
  'subscribe now',
  'buy now',
  'pro is active',
  'voicememory',
  'voice memory',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _entry(String id, {DateTime? createdAt}) => JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript:
          'I $_privateSnippet again even when I was tired today.',
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

List<JournalEntry> _entries(int count) => List.generate(
      count,
      (i) => _entry('e$i', createdAt: DateTime(2026, 6, 1 + i, 12)),
    );

ArchiveHomePriorityInput _priorityInput({
  int savedEntryCount = 0,
  bool returnChangesAvailable = false,
  bool weeklyReviewAvailable = false,
  bool sampleMode = false,
  bool firstWeekPathVisible = true,
  bool dailyArchiveExerciseVisible = true,
  bool archiveClarityProgressVisible = true,
  bool capacityLoopVisible = false,
  bool capacityDecisionOutcomeVisible = false,
  bool capacityCostLaterCheckinVisible = false,
  bool beforeYouSayYesPauseVisible = false,
  bool capacityWeeklyReviewVisible = false,
  bool thenVsNowVisible = false,
  bool archiveCalendarVisible = false,
  bool reviewRitualVisible = false,
  bool milestoneShareVisible = false,
}) =>
    ArchiveHomePriorityInput(
      savedEntryCount: savedEntryCount,
      usableEvidenceCount: savedEntryCount,
      depthLevel: ArchiveDepthLevel.notStarted,
      returnChangesAvailable: returnChangesAvailable,
      weeklyReviewAvailable: weeklyReviewAvailable,
      sampleMode: sampleMode,
      proPreviewPromoVisible: false,
      showEmptySample: savedEntryCount == 0,
      firstWeekPathVisible: firstWeekPathVisible && savedEntryCount < 7,
      dailyArchiveExerciseVisible: dailyArchiveExerciseVisible,
      archiveClarityProgressVisible: archiveClarityProgressVisible,
      capacityLoopVisible: capacityLoopVisible,
      capacityDecisionOutcomeVisible: capacityDecisionOutcomeVisible,
      capacityCostLaterCheckinVisible: capacityCostLaterCheckinVisible,
      beforeYouSayYesPauseVisible: beforeYouSayYesPauseVisible,
      capacityWeeklyReviewVisible: capacityWeeklyReviewVisible,
      thenVsNowVisible: thenVsNowVisible,
      archiveCalendarVisible: archiveCalendarVisible,
      reviewRitualVisible: reviewRitualVisible,
      milestoneShareVisible: milestoneShareVisible,
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
  }
}

void _expectStickyLoopOrder(List<ArchiveHomeSectionId> ranked) {
  final sticky = ArchiveHomePriorityEngine.stickyLoopSequence
      .where(ranked.contains)
      .toList();
  var last = -1;
  for (final id in sticky) {
    final index = ranked.indexOf(id);
    expect(index, greaterThan(last), reason: '$id should follow sticky loop order');
    last = index;
  }
}

void main() {
  const priorityEngine = ArchiveHomePriorityEngine();

  group('Archive Home sticky loop priority', () {
    test('0 entries: first-week path primary, mature cards hidden', () {
      final plan = priorityEngine.build(_priorityInput(savedEntryCount: 0));
      expect(plan.primarySections, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(plan.isHidden(ArchiveHomeSectionId.milestones), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.reviewHistory), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.thenVsNow), isTrue);
    });

    test('1–2 entries: sticky loop beats secondary tools in primary', () {
      final one = priorityEngine.build(_priorityInput(savedEntryCount: 1));
      expect(one.primarySections.take(3), [
        ArchiveHomeSectionId.archiveSummary,
        ArchiveHomeSectionId.firstWeekPath,
        ArchiveHomeSectionId.dailyArchiveExercise,
      ]);
      expect(one.secondarySections, contains(ArchiveHomeSectionId.nextEvidencePlan));

      final two = priorityEngine.build(_priorityInput(savedEntryCount: 2));
      expect(two.primarySections, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(two.primarySections, contains(ArchiveHomeSectionId.dailyArchiveExercise));
      expect(two.isHidden(ArchiveHomeSectionId.betaFeedback), isTrue);
    });

    test('3 entries: beta feedback available in ranked layout', () {
      final plan = priorityEngine.build(_priorityInput(savedEntryCount: 3));
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(ranked, contains(ArchiveHomeSectionId.betaFeedback));
      _expectStickyLoopOrder(ranked);
    });

    test('5–6 entries: clarity/calendar/then-vs-now stay after daily path', () {
      final plan = priorityEngine.build(
        _priorityInput(
          savedEntryCount: 6,
          thenVsNowVisible: true,
          archiveCalendarVisible: true,
        ),
      );
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(ranked.indexOf(ArchiveHomeSectionId.firstWeekPath),
          lessThan(ranked.indexOf(ArchiveHomeSectionId.archiveClarityProgress)));
      expect(plan.primarySections, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(plan.primarySections, isNot(contains(ArchiveHomeSectionId.reviewHistory)));
    });

    test('7+ entries: weekly review and mature tools available but secondary', () {
      final plan = priorityEngine.build(
        _priorityInput(
          savedEntryCount: 8,
          weeklyReviewAvailable: true,
          thenVsNowVisible: true,
          archiveCalendarVisible: true,
          reviewRitualVisible: true,
          milestoneShareVisible: true,
          firstWeekPathVisible: false,
        ),
      );
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(ranked, contains(ArchiveHomeSectionId.reviewHistory));
      expect(ranked, contains(ArchiveHomeSectionId.reviewRitual));
      expect(ranked, contains(ArchiveHomeSectionId.milestoneShare));
      _expectStickyLoopOrder(ranked);
    });

    test('sample mode hides live-user sticky cards', () {
      final plan = priorityEngine.build(
        _priorityInput(
          savedEntryCount: 8,
          sampleMode: true,
          weeklyReviewAvailable: true,
          thenVsNowVisible: true,
          reviewRitualVisible: true,
          milestoneShareVisible: true,
        ),
      );
      expect(plan.primarySections, [ArchiveHomeSectionId.archiveSummary]);
      expect(plan.isHidden(ArchiveHomeSectionId.firstWeekPath), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.reviewRitual), isTrue);
    });
  });

  group('Copy consistency', () {
    test('key surfaces use ArchiveMe and calm sticky-loop language', () {
      _expectNoBannedCopy([
        ...ArchiveHomePriorityCopy.allVisibleCopy(),
        ...TodaysQuestionCopy.allVisibleStrings,
        ...DailyArchiveExerciseCopy.allVisibleStrings,
        ...ReviewRitualCopy.allVisibleStrings,
        ...MilestoneShareCopy.allVisibleStrings,
      ]);
      expect(
        ReviewRitualCopy.cardHeadlineSet.toLowerCase(),
        isNot(contains('knows when')),
      );
      expect(TodaysQuestionCopy.helperText, 'One useful moment is enough.');
    });
  });

  group('Privacy and screenshot safety', () {
    test('milestone share text excludes private journal snippets', () {
      final result = const MilestoneShareEngine().buildFromJournal(
        entries: _entries(3),
        hasWatchTheme: false,
      );
      for (final card in result.cards) {
        expect(card.safeShareText.toLowerCase(), isNot(contains(_privateSnippet)));
      }
    });

    test('milestone cards use fixed copy only', () {
      final result = const MilestoneShareEngine().buildFromJournal(
        entries: _entries(3),
        hasWatchTheme: false,
      );
      for (final card in result.cards) {
        expect(card.safeShareText.toLowerCase(), isNot(contains(_privateSnippet)));
        expect(card.isShareable, isTrue);
      }
    });
  });

  group('Record loop helpers', () {
    test('today question engine uses metadata only', () {
      final result = const TodaysQuestionEngine().buildFromJournal(
        entries: _entries(2),
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );
      expect(result.questionText.toLowerCase(), isNot(contains(_privateSnippet)));
      expect(result.showOnRecord, isTrue);
    });
  });

  test('product map doc exists', () {
    final doc = File('docs/STICKY_LOOP_PRODUCT_MAP.md');
    expect(doc.existsSync(), isTrue);
    final text = doc.readAsStringSync().toLowerCase();
    expect(text, contains('sticky loop'));
    expect(text, contains('#129'));
    expect(text, contains('#136'));
  });
}
