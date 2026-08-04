import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monthly_review/monthly_pattern_review_engine.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';

final _now = DateTime(2026, 6, 15, 9);

KeyMoment _moment(
  String id,
  DateTime date, {
  String text = 'a moment',
  String? resultHint,
  String? patternTitle,
  String? nextCheck,
  List<String> tags = const [],
  KeyMomentSource source = KeyMomentSource.reflection,
}) => KeyMoment(
  id: id,
  date: date,
  title: 'Moment',
  originalText: text,
  shortSummary: text,
  resultHint: resultHint,
  patternTitle: patternTitle,
  nextCheck: nextCheck,
  tags: tags,
  source: source,
);

PatternMemory _memory(
  String id, {
  String title = 'Taking on too much',
  int checkInCount = 2,
  int showedAgainCount = 2,
  List<String> helped = const [],
  List<String> harder = const [],
  String? nextBestQuestion,
}) => PatternMemory(
  id: id,
  patternTitle: title,
  createdAt: _now,
  updatedAt: _now,
  checkInCount: checkInCount,
  showedAgainCount: showedAgainCount,
  helpedMoments: helped,
  harderMoments: harder,
  nextBestQuestion: nextBestQuestion,
);

void main() {
  group('gating', () {
    test('hidden when below all thresholds', () {
      final review = buildMonthlyPatternReview(
        moments: [for (var i = 0; i < 3; i++) _moment('m$i', _now)],
        completedCheckInCount: 1,
        patternMemories: [_memory('p', checkInCount: 1, showedAgainCount: 0)],
        now: _now,
      );
      expect(review, isNull);
    });

    test('shown with at least 8 key moments this month', () {
      final review = buildMonthlyPatternReview(
        moments: [
          for (var i = 0; i < 8; i++)
            _moment(
              'm$i',
              DateTime(2026, 6, 1 + i),
              resultHint: 'lighter',
              text: 'I paused',
            ),
        ],
        now: _now,
      );
      expect(review, isNotNull);
      expect(review!.momentCount, 8);
      expect(review.monthLabel, 'June');
    });

    test('shown with at least 4 completed check-ins', () {
      final review = buildMonthlyPatternReview(
        moments: [
          _moment('m', _now, resultHint: 'heavier', text: 'I carried it'),
        ],
        completedCheckInCount: 4,
        now: _now,
      );
      expect(review, isNotNull);
      expect(review!.checkInCount, 4);
    });

    test('shown with at least 3 repeated pattern memories', () {
      final review = buildMonthlyPatternReview(
        moments: const [],
        patternMemories: [
          _memory('a', title: 'A'),
          _memory('b', title: 'B'),
          _memory('c', title: 'C'),
        ],
        now: _now,
      );
      expect(review, isNotNull);
      expect(review!.keptRepeating, isNotNull);
    });

    test('moments from other months do not count toward the gate', () {
      final review = buildMonthlyPatternReview(
        moments: [
          for (var i = 0; i < 8; i++) _moment('m$i', DateTime(2026, 4, 1 + i)),
        ],
        now: _now,
      );
      expect(review, isNull);
    });
  });

  group('sections', () {
    test('fills repeating, lighter, heavier, helped, and next check', () {
      final review = buildMonthlyPatternReview(
        moments: [
          _moment(
            'a',
            DateTime(2026, 6, 2),
            resultHint: 'lighter',
            text: 'It felt lighter after I paused',
          ),
          _moment(
            'b',
            DateTime(2026, 6, 3),
            resultHint: 'heavier',
            text: 'It felt heavier when I carried it',
          ),
          _moment(
            'c',
            DateTime(2026, 6, 4),
            tags: const ['helped'],
            text: 'I asked for help',
          ),
        ],
        patternMemories: [
          _memory(
            'p',
            title: 'Taking on too much',
            nextBestQuestion: 'What happens right before it shows up?',
          ),
        ],
        completedCheckInCount: 4,
        now: _now,
      );

      expect(review, isNotNull);
      expect(review!.keptRepeating, 'Taking on too much');
      expect(review.gotLighter, contains('lighter'));
      expect(review.gotHeavier, contains('heavier'));
      expect(review.helped, contains('asked for help'));
      expect(review.nextCheck, 'What happens right before it shows up?');
      expect(review.hasNextCheck, isTrue);
    });

    test('never invents empty sections', () {
      final review = buildMonthlyPatternReview(
        moments: [
          _moment(
            'lead',
            DateTime(2026, 6, 1),
            text: 'a quiet note',
            nextCheck: 'What was the moment today?',
          ),
          for (var i = 0; i < 7; i++)
            _moment('m$i', DateTime(2026, 6, 2 + i), text: 'a quiet note'),
        ],
        now: _now,
      );
      expect(review, isNotNull);
      expect(review!.gotLighter, isNull);
      expect(review.gotHeavier, isNull);
      expect(review.helped, isNull);
      expect(review.keptRepeating, isNull);
      expect(review.nextCheck, 'What was the moment today?');
    });

    test('returns null when gated through but nothing to say', () {
      final review = buildMonthlyPatternReview(
        moments: [
          for (var i = 0; i < 8; i++)
            _moment('m$i', DateTime(2026, 6, 1 + i), text: 'a quiet note'),
        ],
        now: _now,
      );
      expect(review, isNull);
    });
  });
}
