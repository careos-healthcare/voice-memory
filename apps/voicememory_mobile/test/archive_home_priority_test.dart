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
  bool thenVsNowVisible = false,
  bool archiveCalendarVisible = false,
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
      thenVsNowVisible: thenVsNowVisible,
      archiveCalendarVisible: archiveCalendarVisible,
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
      expect(plan.primarySections, contains(ArchiveHomeSectionId.quickActions));
      expect(plan.primarySections.indexOf(ArchiveHomeSectionId.firstWeekPath),
          lessThan(plan.primarySections.indexOf(ArchiveHomeSectionId.quickActions)));
    });

    test('archive clarity stays secondary so First Week Path stays primary', () {
      final plan = engine.build(_input(savedEntryCount: 0, showEmptySample: true));

      expect(plan.primarySections, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(plan.primarySections, contains(ArchiveHomeSectionId.dailyArchiveExercise));
      expect(plan.primarySections, isNot(contains(ArchiveHomeSectionId.archiveClarityProgress)));
      expect(
        plan.secondarySections.contains(ArchiveHomeSectionId.archiveClarityProgress) ||
            plan.primarySections.contains(ArchiveHomeSectionId.archiveClarityProgress),
        isTrue,
      );
    });

    test('1-entry layout prioritises First Week Path and Next Evidence Plan', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 1,
          depthLevel: ArchiveDepthLevel.firstEvidence,
        ),
      );

      expect(plan.primarySections.take(3).toList(), [
        ArchiveHomeSectionId.archiveSummary,
        ArchiveHomeSectionId.firstWeekPath,
        ArchiveHomeSectionId.nextEvidencePlan,
      ]);
      expect(plan.isHidden(ArchiveHomeSectionId.evidenceQuality), isTrue);
      expect(plan.isHidden(ArchiveHomeSectionId.milestones), isTrue);
      expect(plan.showMoreArchiveTools, isTrue);
    });

    test('2-entry layout shows Watchlist and Evidence Quality after primary cards', () {
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
        ArchiveHomeSectionId.nextEvidencePlan,
        ArchiveHomeSectionId.dailyArchiveExercise,
      ]);

      final secondary = plan.secondarySections;
      expect(secondary, contains(ArchiveHomeSectionId.watchlist));
      expect(secondary.indexOf(ArchiveHomeSectionId.evidenceQuality), lessThan(
        secondary.indexOf(ArchiveHomeSectionId.returnRitual),
      ));
      expect(plan.isHidden(ArchiveHomeSectionId.milestones), isTrue);
    });

    test('3–4 entry layout prioritises Return Changes when available', () {
      final plan = engine.build(
        _input(
          savedEntryCount: 3,
          returnChangesAvailable: true,
          depthLevel: ArchiveDepthLevel.cautiousBelief,
        ),
      );

      expect(plan.primarySections[1], ArchiveHomeSectionId.firstWeekPath);
      expect(plan.primarySections[2], ArchiveHomeSectionId.returnChanges);
      expect(plan.primarySections.take(4), [
        ArchiveHomeSectionId.archiveSummary,
        ArchiveHomeSectionId.firstWeekPath,
        ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.nextEvidencePlan,
      ]);
      expect(plan.isHidden(ArchiveHomeSectionId.reviewHistory), isTrue);
    });

    test('5+ layout prioritises Weekly Review or Return Changes', () {
      final withReview = engine.build(
        _input(
          savedEntryCount: 5,
          weeklyReviewAvailable: true,
          depthLevel: ArchiveDepthLevel.weeklyReviewReady,
        ),
      );
      expect(withReview.primarySections[1], ArchiveHomeSectionId.firstWeekPath);
      expect(withReview.primarySections[2], ArchiveHomeSectionId.reviewHistory);

      final withChanges = engine.build(
        _input(
          savedEntryCount: 5,
          returnChangesAvailable: true,
          depthLevel: ArchiveDepthLevel.weeklyReviewReady,
        ),
      );
      expect(withChanges.primarySections[1], ArchiveHomeSectionId.firstWeekPath);
      expect(withChanges.primarySections[2], ArchiveHomeSectionId.returnChanges);
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
