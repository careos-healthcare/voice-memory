import 'package:archiveme_mobile/features/export/private_recap_engine.dart';
import 'package:archiveme_mobile/features/export/private_recap_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/monthly_review/monthly_pattern_review_model.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plain text format', () {
    test('includes title, summary, useful moments, next check, and footer', () {
      const recap = PrivateRecap(
        type: PrivateRecapType.pattern,
        title: 'Taking on too much',
        dateRange: 'Seen 4 times',
        summary: 'Based on 4 check-ins',
        usefulMoments: ['Gets lighter when: I paused'],
        nextCheck: 'What happens right before it shows up?',
      );
      final text = recap.plainText;
      expect(text, contains('Taking on too much'));
      expect(text, contains('Seen 4 times'));
      expect(text, contains('Based on 4 check-ins'));
      expect(text, contains('Useful moments'));
      expect(text, contains('- Gets lighter when: I paused'));
      expect(text, contains('Next check'));
      expect(text, contains('What happens right before it shows up?'));
      expect(text.trim().endsWith('Made with ArchiveMe'), isTrue);
    });

    test('omits empty sections without leaving dangling headings', () {
      const recap = PrivateRecap(
        type: PrivateRecapType.keyMoment,
        title: 'A moment',
      );
      final text = recap.plainText;
      expect(text, isNot(contains('Useful moments')));
      expect(text, isNot(contains('Next check')));
      expect(text, contains('A moment'));
      expect(text, contains('Made with ArchiveMe'));
    });
  });

  test('fromKeyMoment preserves the original words and result', () {
    final recap = PrivateRecapEngine.fromKeyMoment(
      KeyMoment(
        id: 'a',
        date: DateTime(2026, 6, 4),
        title: 'Something felt heavier',
        originalText: 'I carried it alone after the meeting.',
        shortSummary: 'I carried it alone.',
        resultHint: 'heavier',
        nextCheck: 'What made it heavier?',
      ),
    );
    expect(recap.type, PrivateRecapType.keyMoment);
    expect(recap.title, 'Something felt heavier');
    expect(
      recap.usefulMoments,
      contains('I carried it alone after the meeting.'),
    );
    expect(recap.usefulMoments, contains('This felt heavier.'));
    expect(recap.nextCheck, 'What made it heavier?');
    expect(recap.plainText, contains('Jun 4, 2026'));
  });

  test('fromPatternMap maps the map sections', () {
    const map = PatternMap(
      patternTitle: 'Taking on too much',
      seenCount: 3,
      usuallyStartsBefore: 'before saying yes',
      oftenFeelsLike: 'heavier',
      getsLighterWhen: 'I paused',
      getsHeavierWhen: 'I carried it alone',
      nextCheck: 'What happens right before it shows up?',
      confidenceLabel: 'Based on 3 check-ins',
    );
    final recap = PrivateRecapEngine.fromPatternMap(map);
    expect(recap.type, PrivateRecapType.pattern);
    expect(recap.title, 'Taking on too much');
    expect(recap.usefulMoments, contains('Usually starts: before saying yes'));
    expect(recap.usefulMoments, contains('Gets lighter when: I paused'));
    expect(recap.nextCheck, 'What happens right before it shows up?');
  });

  test('fromMonthlyReview maps the recap sections', () {
    const review = MonthlyPatternReview(
      monthLabel: 'June',
      momentCount: 9,
      checkInCount: 4,
      keptRepeating: 'Taking on too much',
      gotLighter: 'I paused before replying',
      helped: 'I asked for help',
      nextCheck: 'What happens right before it starts?',
      confidenceLabel: 'Based on 9 moments this month',
    );
    final recap = PrivateRecapEngine.fromMonthlyReview(review);
    expect(recap.type, PrivateRecapType.monthly);
    expect(recap.title, 'June');
    expect(
      recap.usefulMoments,
      contains('This kept repeating: Taking on too much'),
    );
    expect(recap.usefulMoments, contains('This helped: I asked for help'));
    expect(recap.nextCheck, 'What happens right before it starts?');
  });

  test('fromWeeklyRecap maps the week range and next question', () {
    final recap = PrivateRecapEngine.fromWeeklyRecap(
      WeeklyPatternRecap(
        id: 'w',
        memoryId: 'm',
        createdAt: DateTime(2026, 6, 7),
        weekStart: DateTime(2026, 6),
        weekEnd: DateTime(2026, 6, 7),
        type: WeeklyPatternRecapType.repeated,
        patternTitle: 'Taking on too much',
        headline: 'This kept showing up this week.',
        body: 'You checked it 4 times.',
        usefulLine: 'It often starts before saying yes',
        nextQuestion: 'What happens right before it starts?',
        checkInCount: 4,
        shouldShow: true,
      ),
    );
    expect(recap.type, PrivateRecapType.weekly);
    expect(recap.dateRange, 'Jun 1, 2026 – Jun 7, 2026');
    expect(recap.summary, 'You checked it 4 times.');
    expect(recap.usefulMoments, contains('It often starts before saying yes'));
    expect(recap.nextCheck, 'What happens right before it starts?');
  });

  test('fromSelectedMoments lists moments oldest first with a count', () {
    final recap = PrivateRecapEngine.fromSelectedMoments([
      KeyMoment(
        id: 'b',
        date: DateTime(2026, 6, 5),
        title: 'Later',
        originalText: 'second',
        shortSummary: 'second',
      ),
      KeyMoment(
        id: 'a',
        date: DateTime(2026, 6),
        title: 'Earlier',
        originalText: 'first',
        shortSummary: 'first',
        nextCheck: 'What was different?',
      ),
    ], label: 'This week');
    expect(recap.type, PrivateRecapType.selectedRange);
    expect(recap.title, 'This week');
    expect(recap.dateRange, 'Jun 1, 2026 – Jun 5, 2026');
    expect(recap.summary, '2 saved moments.');
    expect(recap.usefulMoments.first, contains('Jun 1, 2026: first'));
    expect(recap.usefulMoments.last, contains('Jun 5, 2026: second'));
    expect(recap.nextCheck, 'What was different?');
  });
}