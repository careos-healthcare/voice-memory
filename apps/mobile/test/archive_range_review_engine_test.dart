import 'package:archiveme_mobile/features/archive_review/archive_range_review_engine.dart';
import 'package:archiveme_mobile/features/archive_review/archive_range_review_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:flutter_test/flutter_test.dart';

KeyMoment _moment(
  String id,
  DateTime date, {
  String? resultHint,
  String? patternTitle,
  List<String> tags = const [],
}) => KeyMoment(
  id: id,
  date: date,
  title: 'Moment $id',
  originalText: 'Original $id',
  shortSummary: 'Summary $id',
  resultHint: resultHint,
  patternTitle: patternTitle,
  tags: tags,
);

void main() {
  final now = DateTime(2026, 6, 6, 12);

  group('date range presets', () {
    test('thisWeek includes last 7 days', () {
      final review = buildArchiveRangeReview(
        moments: [
          _moment('in', DateTime(2026, 6, 6), patternTitle: 'Work pressure'),
          _moment('in2', DateTime(2026, 6), patternTitle: 'Work pressure'),
          _moment('out', DateTime(2026, 5, 30), patternTitle: 'Work pressure'),
        ],
        now: now,
      );
      expect(review.momentCount, 2);
    });

    test('lastWeek excludes this week', () {
      final review = buildArchiveRangeReview(
        moments: [
          _moment('this', DateTime(2026, 6, 6), patternTitle: 'A'),
          _moment('last', DateTime(2026, 5, 30), patternTitle: 'A'),
          _moment('last2', DateTime(2026, 5, 29), patternTitle: 'A'),
          _moment('old', DateTime(2026, 5, 20), patternTitle: 'A'),
        ],
        now: now,
        preset: ArchiveReviewRangePreset.lastWeek,
      );
      expect(review.momentCount, 2);
    });

    test('thisMonth filters current month', () {
      final review = buildArchiveRangeReview(
        moments: [
          _moment('jun', DateTime(2026, 6, 2), patternTitle: 'A'),
          _moment('jun2', DateTime(2026, 6, 4), patternTitle: 'A'),
          _moment('jun3', DateTime(2026, 6, 5), patternTitle: 'A'),
          _moment('may', DateTime(2026, 5, 31), patternTitle: 'A'),
        ],
        now: now,
        preset: ArchiveReviewRangePreset.thisMonth,
      );
      expect(review.momentCount, 3);
    });

    test('last30Days includes rolling window', () {
      final review = buildArchiveRangeReview(
        moments: [
          _moment('in', DateTime(2026, 5, 10), patternTitle: 'A'),
          _moment('in2', DateTime(2026, 6), patternTitle: 'A'),
          _moment('in3', DateTime(2026, 6, 6), patternTitle: 'A'),
          _moment('out', DateTime(2026, 5), patternTitle: 'A'),
        ],
        now: now,
        preset: ArchiveReviewRangePreset.last30Days,
      );
      expect(review.momentCount, 3);
    });
  });

  test('returns notEnoughYet below 3 moments', () {
    final review = buildArchiveRangeReview(
      moments: [
        _moment('a', DateTime(2026, 6, 6), patternTitle: 'A'),
        _moment('b', DateTime(2026, 6, 5), patternTitle: 'A'),
      ],
      now: now,
    );
    expect(review.type, ArchiveRangeReviewType.notEnoughYet);
    expect(review.hasEnoughData, isFalse);
  });

  test('heavier priority beats lighter', () {
    final review = buildArchiveRangeReview(
      moments: [
        _moment(
          '1',
          DateTime(2026, 6, 6),
          resultHint: 'heavier',
          patternTitle: 'P',
        ),
        _moment(
          '2',
          DateTime(2026, 6, 5),
          resultHint: 'heavier',
          patternTitle: 'P',
        ),
        _moment(
          '3',
          DateTime(2026, 6, 4),
          resultHint: 'lighter',
          patternTitle: 'P',
        ),
      ],
      now: now,
    );
    expect(review.type, ArchiveRangeReviewType.heavier);
    expect(review.heavierLine, contains('2 moments'));
  });

  test('lighter priority works', () {
    final review = buildArchiveRangeReview(
      moments: [
        _moment(
          '1',
          DateTime(2026, 6, 6),
          resultHint: 'lighter',
          patternTitle: 'P',
        ),
        _moment(
          '2',
          DateTime(2026, 6, 5),
          resultHint: 'lighter',
          patternTitle: 'P',
        ),
        _moment(
          '3',
          DateTime(2026, 6, 4),
          resultHint: 'same',
          patternTitle: 'P',
        ),
      ],
      now: now,
    );
    expect(review.type, ArchiveRangeReviewType.lighter);
    expect(review.lighterLine, contains('2 moments'));
  });

  test('changed priority works', () {
    final review = buildArchiveRangeReview(
      moments: [
        _moment(
          '1',
          DateTime(2026, 6, 6),
          resultHint: 'changed',
          patternTitle: 'P',
        ),
        _moment(
          '2',
          DateTime(2026, 6, 5),
          resultHint: 'not_today',
          patternTitle: 'P',
        ),
        _moment(
          '3',
          DateTime(2026, 6, 4),
          resultHint: 'same',
          patternTitle: 'P',
        ),
      ],
      now: now,
    );
    expect(review.type, ArchiveRangeReviewType.changed);
    expect(review.changedLine, contains('2 moments'));
  });

  test('repeated fallback works', () {
    final review = buildArchiveRangeReview(
      moments: [
        _moment(
          '1',
          DateTime(2026, 6, 6),
          resultHint: 'same',
          patternTitle: 'Work pressure',
        ),
        _moment(
          '2',
          DateTime(2026, 6, 5),
          resultHint: 'showed_up_again',
          patternTitle: 'Work pressure',
        ),
        _moment('3', DateTime(2026, 6, 4), patternTitle: 'Work pressure'),
      ],
      now: now,
    );
    expect(review.type, ArchiveRangeReviewType.repeated);
    expect(review.repeatedLine, contains('showed up'));
  });

  test('keyMomentIds capped at 10 newest first', () {
    final moments = List.generate(
      12,
      (i) => _moment(
        'm$i',
        DateTime(2026, 6, 6).subtract(Duration(days: i)),
        patternTitle: 'Pattern',
        resultHint: 'same',
      ),
    );
    final review = buildArchiveRangeReview(
      moments: moments,
      now: now,
      preset: ArchiveReviewRangePreset.last30Days,
    );
    expect(review.keyMomentIds.length, 10);
    expect(review.keyMomentIds.first, 'm0');
    expect(review.keyMomentIds.last, 'm9');
  });

  test('nextCheck prefers pattern map then memory then timeline', () {
    final review = buildArchiveRangeReview(
      moments: List.generate(
        3,
        (i) => _moment(
          'm$i',
          DateTime(2026, 6, 6 - i),
          patternTitle: 'P',
          resultHint: 'same',
        ),
      ),
      now: now,
      map: const PatternMap(
        patternTitle: 'P',
        seenCount: 3,
        nextCheck: 'Map check question?',
        confidenceLabel: 'Clear',
      ),
    );
    expect(review.nextCheck, 'Map check question?');
  });
}