import '../moments/key_moment_model.dart';
import '../monthly_review/monthly_pattern_review_model.dart';
import '../pattern_map/pattern_map_model.dart';
import '../pattern_memory/weekly_pattern_recap_model.dart';
import 'private_recap_model.dart';

/// Builds [PrivateRecap]s from what ArchiveMe already knows. Pure mapping — no
/// I/O, no invented facts. Empty inputs stay empty.
abstract class PrivateRecapEngine {
  PrivateRecapEngine._();

  static PrivateRecap fromKeyMoment(KeyMoment moment) {
    final useful = <String>[];
    final summary = moment.shortSummary.trim().isNotEmpty
        ? moment.shortSummary.trim()
        : moment.originalText.trim();
    final original = moment.originalText.trim();
    if (original.isNotEmpty && original != summary) {
      useful.add(original);
    }
    final resultLabel = keyMomentResultLabel(moment.resultHint);
    if (resultLabel != null) {
      useful.add('This $resultLabel.');
    }
    return PrivateRecap(
      type: PrivateRecapType.keyMoment,
      title: moment.title.trim().isNotEmpty ? moment.title.trim() : 'A moment',
      dateRange: _date(moment.date),
      summary: summary.isNotEmpty ? summary : null,
      usefulMoments: useful,
      nextCheck: _clean(moment.nextCheck),
    );
  }

  static PrivateRecap fromPatternMap(PatternMap map) {
    final useful = <String>[];
    _addLabelled(useful, 'Usually starts', map.usuallyStartsBefore);
    _addLabelled(useful, 'Often feels', _feelsLabel(map.oftenFeelsLike));
    _addLabelled(useful, 'Gets lighter when', map.getsLighterWhen);
    _addLabelled(useful, 'Gets heavier when', map.getsHeavierWhen);

    return PrivateRecap(
      type: PrivateRecapType.pattern,
      title: map.patternTitle.trim().isNotEmpty
          ? map.patternTitle.trim()
          : 'A pattern',
      dateRange: _seenLine(map),
      summary: map.confidenceLabel.trim().isNotEmpty
          ? map.confidenceLabel.trim()
          : null,
      usefulMoments: useful,
      nextCheck: _clean(map.nextCheck),
    );
  }

  static PrivateRecap fromMonthlyReview(MonthlyPatternReview review) {
    final useful = <String>[];
    _addLabelled(useful, 'This kept repeating', review.keptRepeating);
    _addLabelled(useful, 'This got lighter', review.gotLighter);
    _addLabelled(useful, 'This got heavier', review.gotHeavier);
    _addLabelled(useful, 'This helped', review.helped);

    return PrivateRecap(
      type: PrivateRecapType.monthly,
      title: review.monthLabel.trim().isNotEmpty
          ? review.monthLabel.trim()
          : 'This month',
      dateRange: review.confidenceLabel.trim().isNotEmpty
          ? review.confidenceLabel.trim()
          : null,
      summary: null,
      usefulMoments: useful,
      nextCheck: _clean(review.nextCheck),
    );
  }

  static PrivateRecap fromWeeklyRecap(WeeklyPatternRecap recap) {
    final useful = <String>[];
    _add(useful, recap.usefulLine);

    return PrivateRecap(
      type: PrivateRecapType.weekly,
      title: recap.patternTitle.trim().isNotEmpty
          ? recap.patternTitle.trim()
          : 'This week',
      dateRange: '${_date(recap.weekStart)} – ${_date(recap.weekEnd)}',
      summary: recap.body.trim().isNotEmpty
          ? recap.body.trim()
          : _clean(recap.headline),
      usefulMoments: useful,
      nextCheck: _clean(recap.nextQuestion),
    );
  }

  static PrivateRecap fromSelectedMoments(
    List<KeyMoment> moments, {
    String? label,
  }) {
    final sorted = [...moments]..sort((a, b) => a.date.compareTo(b.date));
    final useful = <String>[];
    for (final m in sorted) {
      final summary = m.shortSummary.trim().isNotEmpty
          ? m.shortSummary.trim()
          : m.originalText.trim();
      if (summary.isEmpty) continue;
      useful.add('${_date(m.date)}: $summary');
    }

    String? range;
    if (sorted.isNotEmpty) {
      final first = _date(sorted.first.date);
      final last = _date(sorted.last.date);
      range = first == last ? first : '$first – $last';
    }

    String? nextCheck;
    for (final m in sorted.reversed) {
      final q = (m.nextCheck ?? '').trim();
      if (q.isNotEmpty) {
        nextCheck = q;
        break;
      }
    }

    final count = useful.length;
    final summary = count == 0
        ? null
        : (count == 1 ? '1 saved moment.' : '$count saved moments.');

    return PrivateRecap(
      type: PrivateRecapType.selectedRange,
      title: (label ?? '').trim().isNotEmpty
          ? label!.trim()
          : 'Selected moments',
      dateRange: range,
      summary: summary,
      usefulMoments: useful,
      nextCheck: nextCheck,
    );
  }

  static void _add(List<String> into, String? value) {
    final v = (value ?? '').trim();
    if (v.isNotEmpty) into.add(v);
  }

  static void _addLabelled(List<String> into, String label, String? value) {
    final v = (value ?? '').trim();
    if (v.isNotEmpty) into.add('$label: $v');
  }

  static String? _clean(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static String? _feelsLabel(String? feels) {
    final v = (feels ?? '').trim();
    if (v.isEmpty) return null;
    return v == 'different' ? 'different each time' : v;
  }

  static String? _seenLine(PatternMap map) {
    if (map.seenCount <= 0) return null;
    final times = map.seenCount == 1 ? '1 time' : '${map.seenCount} times';
    final last = map.lastSeenDate;
    if (last == null) return 'Seen $times';
    return 'Seen $times · last ${_date(last)}';
  }

  static String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
