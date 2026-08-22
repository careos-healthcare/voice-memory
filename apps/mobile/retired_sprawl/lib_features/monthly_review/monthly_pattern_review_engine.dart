import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/moments/moment_tag_model.dart';
import 'package:archiveme_mobile/features/monthly_review/monthly_pattern_review_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';

/// Gating thresholds — the recap only appears once there is enough to look back
/// on, so it never feels thin or invented.
const int kMonthlyReviewMinMoments = 8;
const int kMonthlyReviewMinCheckIns = 4;
const int kMonthlyReviewMinRepeatedPatterns = 3;

/// A pattern memory counts as "repeated" once it has shown up across at least
/// two check-ins.
const int _repeatedThreshold = 2;

/// Builds a [MonthlyPatternReview] from this month's saved moments and what
/// ArchiveMe remembers about recurring patterns. Returns null when there is not
/// yet enough to look back on.
MonthlyPatternReview? buildMonthlyPatternReview({
  List<KeyMoment> moments = const [],
  List<PatternMemory> patternMemories = const [],
  int completedCheckInCount = 0,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final monthMoments =
      moments
          .where(
            (m) => m.date.year == clock.year && m.date.month == clock.month,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final repeatedPatterns = patternMemories
      .where((m) => m.checkInCount >= _repeatedThreshold)
      .toList();

  final enough =
      monthMoments.length >= kMonthlyReviewMinMoments ||
      completedCheckInCount >= kMonthlyReviewMinCheckIns ||
      repeatedPatterns.length >= kMonthlyReviewMinRepeatedPatterns;
  if (!enough) return null;

  final review = MonthlyPatternReview(
    monthLabel: _monthName(clock.month),
    momentCount: monthMoments.length,
    checkInCount: completedCheckInCount,
    keptRepeating: _keptRepeating(monthMoments, patternMemories),
    gotLighter: _gotLighter(monthMoments, patternMemories),
    gotHeavier: _gotHeavier(monthMoments, patternMemories),
    helped: _helped(monthMoments, patternMemories),
    nextCheck: _nextCheck(monthMoments, patternMemories),
    confidenceLabel: _confidence(monthMoments.length, completedCheckInCount),
  );

  // Even when gated through, only show when there is something to say.
  if (!review.hasContent) return null;
  return review;
}

/// The pattern that recurred most this month.
String? _keptRepeating(
  List<KeyMoment> monthMoments,
  List<PatternMemory> memories,
) {
  PatternMemory? best;
  for (final m in memories) {
    if (m.showedAgainCount <= 0 && m.checkInCount < _repeatedThreshold) {
      continue;
    }
    if (best == null || m.showedAgainCount > best.showedAgainCount) {
      best = m;
    }
  }
  if (best != null && best.patternTitle.trim().isNotEmpty) {
    return best.patternTitle.trim();
  }

  // Fall back to the most common pattern title among "showed up again" moments.
  final counts = <String, int>{};
  for (final m in monthMoments) {
    final repeated =
        m.resultHint == 'same' || m.resultHint == 'showed_up_again';
    final title = (m.patternTitle ?? '').trim();
    if (repeated && title.isNotEmpty) {
      counts[title] = (counts[title] ?? 0) + 1;
    }
  }
  String? top;
  var topCount = 0;
  counts.forEach((title, count) {
    if (count > topCount) {
      topCount = count;
      top = title;
    }
  });
  return topCount >= 2 ? top : null;
}

String? _gotLighter(
  List<KeyMoment> monthMoments,
  List<PatternMemory> memories,
) {
  final fromMoment = _firstSummary(monthMoments, hint: 'lighter');
  if (fromMoment != null) return fromMoment;
  return _firstFromMemories(memories, (m) => m.helpedMoments);
}

String? _gotHeavier(
  List<KeyMoment> monthMoments,
  List<PatternMemory> memories,
) {
  final fromMoment = _firstSummary(monthMoments, hint: 'heavier');
  if (fromMoment != null) return fromMoment;
  return _firstFromMemories(memories, (m) => m.harderMoments);
}

String? _helped(List<KeyMoment> monthMoments, List<PatternMemory> memories) {
  final fromMoment = _firstSummary(monthMoments, tag: MomentTag.helped);
  if (fromMoment != null) return fromMoment;
  return _firstFromMemories(memories, (m) => m.helpedMoments);
}

String? _nextCheck(List<KeyMoment> monthMoments, List<PatternMemory> memories) {
  for (final m in memories) {
    final q = (m.nextBestQuestion ?? '').trim();
    if (q.isNotEmpty) return q;
  }
  for (final m in monthMoments) {
    final q = (m.nextCheck ?? '').trim();
    if (q.isNotEmpty) return q;
  }
  // Only offer a generic next check when something actually repeated.
  if (_keptRepeating(monthMoments, memories) != null) {
    return 'What happens right before it starts?';
  }
  return null;
}

String? _firstSummary(List<KeyMoment> moments, {String? hint, MomentTag? tag}) {
  for (final m in moments) {
    if (m.shortSummary.trim().isEmpty) continue;
    if (hint != null && m.resultHint == hint) return m.shortSummary.trim();
    if (tag != null && m.hasTag(tag)) return m.shortSummary.trim();
  }
  return null;
}

String? _firstFromMemories(
  List<PatternMemory> memories,
  List<String> Function(PatternMemory) pick,
) {
  for (final m in memories) {
    for (final v in pick(m)) {
      if (v.trim().isNotEmpty) return v.trim();
    }
  }
  return null;
}

String _confidence(int momentCount, int checkInCount) {
  if (momentCount > 0) {
    final noun = momentCount == 1 ? 'moment' : 'moments';
    return 'Based on $momentCount $noun this month';
  }
  if (checkInCount > 0) {
    final noun = checkInCount == 1 ? 'check' : 'checks';
    return 'Based on $checkInCount $noun this month';
  }
  return 'This month';
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month < 1 || month > 12) return 'This month';
  return names[month - 1];
}