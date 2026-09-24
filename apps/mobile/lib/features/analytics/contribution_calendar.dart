import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// GitHub-style week columns. Sunday is the first row.
class ContributionCalendarLayout {
  ContributionCalendarLayout({required DateTime today, this.weekCount = 27})
    : today = dateOnly(today),
      start = _startSunday(dateOnly(today), weekCount);

  static const double cell = 14;
  static const double gap = 3;
  static const double stride = cell + gap;
  static const double labelWidth = 16;
  static const double header = 16;

  final DateTime today;
  final DateTime start;
  final int weekCount;

  double get width => labelWidth + weekCount * stride;
  double get height => header + 7 * stride;

  DateTime? dayAt(Offset local) {
    final x = local.dx - labelWidth;
    final y = local.dy - header;
    if (x < 0 || y < 0) return null;
    final column = x ~/ stride;
    final row = y ~/ stride;
    if (column < 0 || column >= weekCount || row < 0 || row > 6) return null;
    if ((x % stride) > cell || (y % stride) > cell) return null;
    final day = start.add(Duration(days: column * 7 + row));
    if (day.isAfter(today)) return null;
    return day;
  }

  Rect rectFor(DateTime day) {
    final local = dateOnly(day);
    final delta = local.difference(start).inDays;
    final column = delta ~/ 7;
    final row = delta % 7;
    return Rect.fromLTWH(
      labelWidth + column * stride,
      header + row * stride,
      cell,
      cell,
    );
  }

  static DateTime _startSunday(DateTime today, int weekCount) {
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    return sunday.subtract(Duration(days: (weekCount - 1) * 7));
  }
}

/// Cell color from how many moments landed that day and their average tone.
Color dayCellColor({required int count, required double sentiment}) {
  if (count <= 0) return AppTokens.neutral200;
  final level = switch (count) {
    1 => 0,
    2 => 1,
    <= 4 => 2,
    _ => 3,
  };
  if (sentiment < -0.05) {
    return const [
      Color(0xFFF3D6D0),
      Color(0xFFE7B2A8),
      Color(0xFFC47A6A),
      Color(0xFF9A3412),
    ][level];
  }
  return const [
    AppTokens.primary200,
    AppTokens.primary400,
    AppTokens.primary600,
    AppTokens.primary800,
  ][level];
}

/// Contribution grid painted and hit-tested by its own [RenderBox].
class ContributionCalendar extends LeafRenderObjectWidget {
  const ContributionCalendar({
    required this.days,
    required this.today,
    required this.onDayTap,
    this.selectedDay,
    super.key,
  });

  final Map<String, DayStats> days;
  final DateTime today;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;

  @override
  RenderContributionCalendar createRenderObject(BuildContext context) {
    return RenderContributionCalendar(
      days: days,
      today: today,
      selectedDay: selectedDay,
      onDayTap: onDayTap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderContributionCalendar renderObject,
  ) {
    renderObject
      ..updateDays(days)
      ..updateToday(today)
      ..updateSelectedDay(selectedDay)
      ..onDayTap = onDayTap;
  }
}

class RenderContributionCalendar extends RenderBox {
  RenderContributionCalendar({
    required this._days,
    required DateTime today,
    required DateTime? selectedDay,
    required this.onDayTap,
  }) : _layout = ContributionCalendarLayout(today: today),
       _selectedDay = selectedDay == null ? null : dateOnly(selectedDay);

  Map<String, DayStats> _days;
  ContributionCalendarLayout _layout;
  DateTime? _selectedDay;
  ValueChanged<DateTime> onDayTap;

  ContributionCalendarLayout get calendarLayout => _layout;

  void updateDays(Map<String, DayStats> value) {
    if (identical(_days, value)) return;
    _days = value;
    markNeedsPaint();
  }

  void updateToday(DateTime value) {
    final next = dateOnly(value);
    if (next == _layout.today) return;
    _layout = ContributionCalendarLayout(today: next);
    markNeedsLayout();
  }

  void updateSelectedDay(DateTime? value) {
    final next = value == null ? null : dateOnly(value);
    if (next == _selectedDay) return;
    _selectedDay = next;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(_layout.width, _layout.height));
  }

  @override
  bool hitTestSelf(Offset position) => size.contains(position);

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is! PointerUpEvent) return;
    final day = _layout.dayAt(event.localPosition);
    if (day != null) onDayTap(day);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final label = TextPainter(textDirection: TextDirection.ltr);
    try {
      const letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
      for (var row = 0; row < letters.length; row++) {
        label
          ..text = TextSpan(
            text: letters[row],
            style: const TextStyle(color: AppTokens.neutral500, fontSize: 9),
          )
          ..layout()
          ..paint(
            canvas,
            offset +
                Offset(
                  0,
                  ContributionCalendarLayout.header +
                      row * ContributionCalendarLayout.stride,
                ),
          );
      }

      var previousMonth = 0;
      for (var column = 0; column < _layout.weekCount; column++) {
        final weekStart = _layout.start.add(Duration(days: column * 7));
        if (weekStart.month != previousMonth &&
            !weekStart.isAfter(_layout.today)) {
          previousMonth = weekStart.month;
          label
            ..text = TextSpan(
              text: _months[weekStart.month - 1],
              style: const TextStyle(color: AppTokens.neutral500, fontSize: 9),
            )
            ..layout()
            ..paint(
              canvas,
              offset +
                  Offset(
                    ContributionCalendarLayout.labelWidth +
                        column * ContributionCalendarLayout.stride,
                    0,
                  ),
            );
        }
        for (var row = 0; row < 7; row++) {
          final day = _layout.start.add(Duration(days: column * 7 + row));
          if (day.isAfter(_layout.today)) continue;
          final stats = _days[dayKey(day)];
          final color = dayCellColor(
            count: stats?.count ?? 0,
            sentiment: stats?.meanSentiment ?? 0,
          );
          final rect = _layout.rectFor(day).shift(offset);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()..color = color,
          );
          if (_selectedDay == day) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                rect.inflate(1),
                const Radius.circular(3),
              ),
              Paint()
                ..color = AppTokens.neutral900
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
        }
      }
    } finally {
      label.dispose();
    }
  }
}

const _months = [
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
