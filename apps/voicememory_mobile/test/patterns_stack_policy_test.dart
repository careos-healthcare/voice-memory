import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/patterns/patterns_stack_policy.dart';

void main() {
  group('decidePatternsStack', () {
    test('active check-in appears first', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: true,
        hasArchiveMemory: true,
        hasNextCheck: true,
        hasArchiveCleanView: true,
        hasPatternProfile: true,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: true,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
      );
      expect(d.sections.first, PatternsSectionType.activeCheckIn);
    });

    test('archive memory appears before manual navigation', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: true,
        hasArchiveCleanView: true,
        hasPatternProfile: true,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: true,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
      );
      expect(
        d.sections.indexOf(PatternsSectionType.archiveMemory),
        lessThan(d.sections.indexOf(PatternsSectionType.archiveNavigation)),
      );
      expect(
        d.sections.indexOf(PatternsSectionType.patternProfile),
        lessThan(d.sections.indexOf(PatternsSectionType.archiveNavigation)),
      );
    });

    test(
      'archive navigation suppresses separate Ask Archive and Find Moment cards',
      () {
        final d = decidePatternsStack(
          hasActiveCheckIn: false,
          hasArchiveMemory: true,
          hasNextCheck: false,
          hasArchiveCleanView: true,
          hasPatternProfile: false,
          hasRangeReview: false,
          hasArchiveCompression: false,
          hasTimeline: false,
          hasProgress: false,
          hasRecap: false,
          hasShare: false,
          hasAnyMoment: true,
        );
        expect(d.suppressSeparateAskArchiveCard, isTrue);
        expect(d.suppressSeparateFindMomentCard, isTrue);
        expect(d.suppressSeparatePatternMapCard, isTrue);
      },
    );

    test(
      'Pattern Profile suppresses duplicate Pattern Map but timeline stays visible',
      () {
        final d = decidePatternsStack(
          hasActiveCheckIn: false,
          hasArchiveMemory: true,
          hasNextCheck: true,
          hasArchiveCleanView: true,
          hasPatternProfile: true,
          hasRangeReview: false,
          hasArchiveCompression: false,
          hasTimeline: true,
          hasProgress: false,
          hasRecap: false,
          hasShare: false,
          hasAnyMoment: true,
        );
        expect(d.suppressSeparatePatternMapCard, isTrue);
        expect(d.suppressSeparateTimelineCard, isTrue);
        expect(d.includes(PatternsSectionType.timeline), isTrue);
        expect(
          d.sections.indexOf(PatternsSectionType.timeline),
          lessThan(d.sections.indexOf(PatternsSectionType.patternProfile)),
        );
      },
    );

    test('empty state only when no moments and no archive memory', () {
      final empty = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: false,
        hasNextCheck: false,
        hasArchiveCleanView: false,
        hasPatternProfile: false,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: false,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: false,
      );
      expect(empty.includes(PatternsSectionType.emptyState), isTrue);

      final withMemory = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: false,
        hasArchiveCleanView: false,
        hasPatternProfile: false,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: false,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: false,
      );
      expect(withMemory.includes(PatternsSectionType.emptyState), isFalse);
    });

    test(
      'suppresses lower-priority Use this check when memory has next check',
      () {
        final d = decidePatternsStack(
          hasActiveCheckIn: false,
          hasArchiveMemory: true,
          hasNextCheck: true,
          hasArchiveCleanView: false,
          hasPatternProfile: false,
          hasRangeReview: false,
          hasArchiveCompression: false,
          hasTimeline: true,
          hasProgress: false,
          hasRecap: false,
          hasShare: false,
          hasAnyMoment: true,
        );
        expect(d.suppressLowerPriorityCtas, isTrue);
      },
    );

    test('standalone next check section when no archive memory', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: false,
        hasNextCheck: true,
        hasArchiveCleanView: false,
        hasPatternProfile: false,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: false,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
      );
      expect(d.includes(PatternsSectionType.nextCheck), isTrue);
      expect(d.includes(PatternsSectionType.archiveMemory), isFalse);
    });

    test('recap and share appear lower in stack', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: false,
        hasArchiveCleanView: true,
        hasPatternProfile: true,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: true,
        hasProgress: true,
        hasRecap: true,
        hasShare: true,
        hasAnyMoment: true,
      );
      expect(
        d.sections.indexOf(PatternsSectionType.recap),
        greaterThan(d.sections.indexOf(PatternsSectionType.patternProfile)),
      );
      expect(
        d.sections.indexOf(PatternsSectionType.share),
        greaterThan(d.sections.indexOf(PatternsSectionType.recap)),
      );
    });
    test('range review appears after pattern profile', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: false,
        hasArchiveCleanView: true,
        hasPatternProfile: true,
        hasRangeReview: true,
        hasArchiveCompression: false,
        hasTimeline: true,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
      );
      expect(d.includes(PatternsSectionType.rangeReview), isTrue);
      expect(
        d.sections.indexOf(PatternsSectionType.rangeReview),
        greaterThan(d.sections.indexOf(PatternsSectionType.patternProfile)),
      );
    });
    test('archive compression appears after pattern profile', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: false,
        hasArchiveCleanView: true,
        hasPatternProfile: true,
        hasRangeReview: false,
        hasArchiveCompression: true,
        hasTimeline: true,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
      );
      expect(d.includes(PatternsSectionType.archiveCompression), isTrue);
      expect(
        d.sections.indexOf(PatternsSectionType.archiveCompression),
        greaterThan(d.sections.indexOf(PatternsSectionType.patternProfile)),
      );
    });

    test('due check status suppresses compact objective', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: true,
        hasArchiveMemory: false,
        hasNextCheck: false,
        hasArchiveCleanView: false,
        hasPatternProfile: false,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: false,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
        hasDueCheckStatusCard: true,
      );
      expect(d.showCurrentObjectiveCard, isFalse);
    });

    test('shows compact objective when no due status card', () {
      final d = decidePatternsStack(
        hasActiveCheckIn: false,
        hasArchiveMemory: true,
        hasNextCheck: true,
        hasArchiveCleanView: false,
        hasPatternProfile: false,
        hasRangeReview: false,
        hasArchiveCompression: false,
        hasTimeline: false,
        hasProgress: false,
        hasRecap: false,
        hasShare: false,
        hasAnyMoment: true,
        hasDueCheckStatusCard: false,
      );
      expect(d.showCurrentObjectiveCard, isTrue);
    });
  });
}
