import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_copy.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  'VoiceMemory',
  'voice memory',
];

ArchiveHomePriorityInput _input({
  int savedEntryCount = 0,
  int usableEvidenceCount = 0,
  ArchiveDepthLevel depthLevel = ArchiveDepthLevel.notStarted,
  bool returnChangesAvailable = false,
  bool weeklyReviewAvailable = false,
  bool sampleMode = false,
  bool proPreviewPromoVisible = false,
  bool showEmptySample = false,
  bool firstWeekPathVisible = true,
  bool dailyArchiveExerciseVisible = true,
  bool archiveClarityProgressVisible = true,
  bool capacityLoopVisible = false,
  bool capacityCostLaterCheckinVisible = false,
  bool thenVsNowVisible = false,
  bool archiveCalendarVisible = false,
  bool reviewRitualVisible = false,
  bool milestoneShareVisible = false,
}) =>
    ArchiveHomePriorityInput(
      savedEntryCount: savedEntryCount,
      usableEvidenceCount: usableEvidenceCount,
      depthLevel: depthLevel,
      returnChangesAvailable: returnChangesAvailable,
      weeklyReviewAvailable: weeklyReviewAvailable,
      sampleMode: sampleMode,
      proPreviewPromoVisible: proPreviewPromoVisible,
      showEmptySample: showEmptySample,
      firstWeekPathVisible: firstWeekPathVisible && savedEntryCount < 7,
      dailyArchiveExerciseVisible: dailyArchiveExerciseVisible,
      archiveClarityProgressVisible: archiveClarityProgressVisible,
      capacityLoopVisible: capacityLoopVisible,
      capacityCostLaterCheckinVisible: capacityCostLaterCheckinVisible,
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
        isNot(contains(word.toLowerCase())),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  const engine = ArchiveHomePriorityEngine();

  group('ArchiveHomePriorityEngine', () {
    test('0-entry layout hides advanced clutter', () {
      final plan = engine.build(_input(savedEntryCount: 0, showEmptySample: true));

      expect(plan.primarySections, contains(ArchiveHomeSectionId.archiveSummary));
      expect(plan.isHidden(ArchiveHomeSectionId.milestones), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.evidenceQuality), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.returnChanges), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.nextEvidencePlan), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.watchlist), isTrue);

      expect(plan.primarySections, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(plan.primarySections, contains(ArchiveHomeSectionId.dailyArchiveExercise));
      expect(plan.secondarySections, contains(ArchiveHomeSectionId.quickActions));
      expect(
        plan.primarySections.indexOf(ArchiveHomeSectionId.firstWeekPath),
        lessThan(plan.primarySections.indexOf(ArchiveHomeSectionId.dailyArchiveExercise)),
      );
    });

    test('archive clarity follows daily exercise in sticky loop order', () {
      final plan = engine.build(_input(savedEntryCount: 0, showEmptySample: true));
      final ranked = [...plan.primarySections, ...plan.secondarySections];

      expect(ranked, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(ranked, contains(ArchiveHomeSectionId.dailyArchiveExercise));
      expect(ranked, contains(ArchiveHomeSectionId.archiveClarityProgress));
      expect(
        ranked.indexOf(ArchiveHomeSectionId.dailyArchiveExercise),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.archiveClarityProgress)),
      );
    });

    test('1-entry layout prioritises First Week Path and Daily Exercise', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 1,
          depthLevel: ArchiveDepthLevel.firstEvidence,
        ),
      );

      expect(plan.primarySections.take(3).toList(), [
        ArchiveHomeSectionId.archiveSummary,
        ArchiveHomeSectionId.firstWeekPath,
        ArchiveHomeSectionId.dailyArchiveExercise,
      ]);
      expect(plan.isHidden(ArchiveHomeSectionId.evidenceQuality), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.milestones), isTrue);
      expect(plan.secondarySections, contains(ArchiveHomeSectionId.nextEvidencePlan));
      expect(plan.showMoreArchiveTools, isTrue);
    });

    test('2-entry layout keeps sticky loop before secondary tools', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 2,
          depthLevel: ArchiveDepthLevel.startingToCompare,
          usableEvidenceCount: 2,
        ),
      );

      expect(plan.primarySections, [
        ArchiveHomeSectionId.archiveSummary,
        ArchiveHomeSectionId.firstWeekPath,
        ArchiveHomeSectionId.dailyArchiveExercise,
        ArchiveHomeSectionId.archiveClarityProgress,
      ]);

      final secondary = plan.secondarySections;
      expect(secondary, contains(ArchiveHomeSectionId.nextEvidencePlan));
      expect(secondary, contains(ArchiveHomeSectionId.watchlist));
      expect(
        secondary.indexOf(ArchiveHomeSectionId.dailyArchiveExercise),
        -1,
      );
      expect(plan.isHidden(ArchiveHomeSectionId.milestones), isTrue);
    });

    test('3–4 entry layout keeps Return Changes secondary', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 3,
          returnChangesAvailable: true,
          depthLevel: ArchiveDepthLevel.cautiousBelief,
        ),
      );

      expect(plan.primarySections[1], ArchiveHomeSectionId.firstWeekPath);
      expect(plan.primarySections[2], ArchiveHomeSectionId.dailyArchiveExercise);
      expect(plan.primarySections, isNot(contains(ArchiveHomeSectionId.returnChanges)));
      expect(plan.secondarySections, contains(ArchiveHomeSectionId.returnChanges));
      expect(plan.isHidden(ArchiveHomeSectionId.reviewHistory), isTrue);
    });

    test('5+ layout keeps weekly review in secondary until sticky loop fills primary', () {
      final withReview = engine.build(
        _input(
          savedEntryCount: 5,
          weeklyReviewAvailable: true,
          depthLevel: ArchiveDepthLevel.weeklyReviewReady,
        ),
      );
      expect(withReview.primarySections[1], ArchiveHomeSectionId.firstWeekPath);
      expect(withReview.primarySections[2], ArchiveHomeSectionId.dailyArchiveExercise);
      expect(withReview.secondarySections, contains(ArchiveHomeSectionId.reviewHistory));

      final withChanges = engine.build(
        _input(
          savedEntryCount: 5,
          returnChangesAvailable: true,
          depthLevel: ArchiveDepthLevel.weeklyReviewReady,
        ),
      );
      expect(withChanges.primarySections[1], ArchiveHomeSectionId.firstWeekPath);
      expect(withChanges.secondarySections, contains(ArchiveHomeSectionId.returnChanges));
    });

    test('sticky loop order is stable across entry counts', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 8,
          weeklyReviewAvailable: true,
          returnChangesAvailable: true,
          thenVsNowVisible: true,
          archiveCalendarVisible: true,
          reviewRitualVisible: true,
          milestoneShareVisible: true,
        ),
      );

      final ranked = [
        ...plan.primarySections,
        ...plan.secondarySections,
      ];
      final sticky = ArchiveHomePriorityEngine.stickyLoopSections(
        _input(
          savedEntryCount: 8,
          weeklyReviewAvailable: true,
          returnChangesAvailable: true,
          thenVsNowVisible: true,
          archiveCalendarVisible: true,
          reviewRitualVisible: true,
          milestoneShareVisible: true,
        ),
      );
      var lastIndex = -1;
      for (final id in sticky) {
        final index = ranked.indexOf(id);
        expect(index, greaterThan(lastIndex));
        lastIndex = index;
      }
    });

    test('10+ layout allows Pro Preview but no purchase CTAs in copy', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 10,
          weeklyReviewAvailable: true,
          proPreviewPromoVisible: true,
          depthLevel: ArchiveDepthLevel.longTermBuilding,
        ),
      );

      expect(plan.proPreviewProminent, isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.proPreview), isFalse);
      expect(
        plan.primarySections.contains(ArchiveHomeSectionId.proPreview) ||
            plan.secondarySections.contains(ArchiveHomeSectionId.proPreview),
        isTrue,
      );

      _expectNoBannedCopy(ArchiveHomePriorityCopy.allVisibleCopy());
    });

    test('sample/screenshot mode stays clean', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 5,
          sampleMode: true,
          weeklyReviewAvailable: true,
          returnChangesAvailable: true,
        ),
      );

      expect(plan.primarySections, [ArchiveHomeSectionId.archiveSummary]);
      expect(plan.secondarySections, isEmpty);
      expect(plan.showMoreArchiveTools, isFalse);
      expect(plan.hiddenSections.length, greaterThan(5));
    });

    test('all sections remain reachable via primary or secondary when not hidden', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 8,
          weeklyReviewAvailable: true,
          returnChangesAvailable: true,
          proPreviewPromoVisible: true,
          depthLevel: ArchiveDepthLevel.weeklyReviewReady,
        ),
      );

      final reachable = {
        ...plan.primarySections,
        ...plan.secondarySections,
      };
      for (final id in ArchiveHomeSectionId.values) {
        if (plan.isHidden(id)) continue;
        if (id == ArchiveHomeSectionId.sampleArchive) continue;
        if (id == ArchiveHomeSectionId.introHint) continue;
        if (id == ArchiveHomeSectionId.firstWeekPath) continue;
        if (id == ArchiveHomeSectionId.dailyArchiveExercise) continue;
        if (id == ArchiveHomeSectionId.archiveClarityProgress) continue;
        expect(reachable, contains(id), reason: '$id should remain reachable');
      }
    });

    test('copy uses ArchiveMe branding and calm tone', () {
      final copy = ArchiveHomePriorityCopy.allVisibleCopy().join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(ArchiveHomePriorityCopy.allVisibleCopy());
    });

    test('primary area caps at summary plus three cards', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 8,
          weeklyReviewAvailable: true,
          returnChangesAvailable: true,
          proPreviewPromoVisible: true,
        ),
      );

      expect(plan.primarySections.length, lessThanOrEqualTo(4));
      expect(plan.primarySections.first, ArchiveHomeSectionId.archiveSummary);
      if (plan.secondarySections.isNotEmpty) {
        expect(plan.showMoreArchiveTools, isTrue);
      }
    });
  });
}
