import 'package:archiveme_mobile/features/habits/goal_velocity_calculator.dart';
import 'package:archiveme_mobile/features/habits/habit_tracker_service.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// One habit prepared for the dashboard.
class HabitDashboardCard {
  const HabitDashboardCard({
    required this.habit,
    required this.window,
    this.momentLabels = const {},
  });

  final Habit habit;
  final GoalVelocityWindow window;
  final Map<String, String> momentLabels;
}

/// Streaks, velocity, and the moments behind each habit.
class HabitsDashboardScreen extends StatelessWidget {
  const HabitsDashboardScreen({
    required this.cards,
    super.key,
    this.onLogHabit,
    this.onOpenMoment,
  });

  final List<HabitDashboardCard> cards;
  final VoidCallback? onLogHabit;
  final void Function(String entryId)? onOpenMoment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('habits_dashboard_screen'),
      appBar: AppBar(title: const Text('Habits')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('habit_log_action'),
        onPressed: onLogHabit,
        label: const Text('+ Log Habit'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spacing3),
        children: [
          for (final card in cards)
            _HabitPanel(card: card, onOpen: onOpenMoment),
        ],
      ),
    );
  }
}

class _HabitPanel extends StatelessWidget {
  const _HabitPanel({required this.card, required this.onOpen});

  final HabitDashboardCard card;
  final void Function(String entryId)? onOpen;

  @override
  Widget build(BuildContext context) {
    final window = card.window;
    final completed = window.completedSentiment;
    final missed = window.missedSentiment;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.habit.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spacing2),
          Text('${window.weeklyStreak}-week streak'),
          Text(
            '${(window.consistency * 100).round()}% of the last ${window.days} days',
          ),
          Text('${window.perWeek.toStringAsFixed(1)} per week'),
          const SizedBox(height: AppTokens.spacing2),
          _StreakGrid(days: window.recentDays),
          const SizedBox(height: AppTokens.spacing2),
          _VelocitySparkline(counts: window.weeklyCounts),
          if (completed != null || missed != null) ...[
            const SizedBox(height: AppTokens.spacing2),
            Text(
              'Completed days ${_tone(completed)} · Missed days ${_tone(missed)}',
              key: Key('habit_sentiment_${card.habit.id}'),
            ),
          ],
          if (window.entryIds.isNotEmpty)
            ViewEvidenceInlineLink(
              entryIds: window.entryIds,
              surface: 'habits',
              claimContext: card.habit.title,
              onViewEvidence: onOpen == null
                  ? null
                  : () => onOpen!(window.entryIds.first),
            ),
          Wrap(
            spacing: AppTokens.spacing2,
            children: [
              for (final entryId in window.entryIds)
                ActionChip(
                  key: Key('habit_moment_$entryId'),
                  label: Text(card.momentLabels[entryId] ?? 'Moment'),
                  onPressed: onOpen == null ? null : () => onOpen!(entryId),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _tone(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(2);
  }
}

class _StreakGrid extends StatelessWidget {
  const _StreakGrid({required this.days});

  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('habit_streak_grid'),
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final done in days)
          Container(
            width: 14,
            height: 14,
            color: done ? AppTokens.primary600 : AppTokens.neutral200,
          ),
      ],
    );
  }
}

class _VelocitySparkline extends StatelessWidget {
  const _VelocitySparkline({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('habit_velocity_sparkline'),
      size: const Size(160, 36),
      painter: _SparklinePainter(counts),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.counts);

  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;
    final peak = counts.reduce((a, b) => a > b ? a : b);
    final scale = peak == 0 ? 0.0 : size.height / peak;
    final paint = Paint()
      ..color = AppTokens.primary600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var index = 0; index < counts.length; index++) {
      final x = counts.length == 1
          ? size.width / 2
          : size.width * index / (counts.length - 1);
      final y = size.height - (counts[index] * scale);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.counts != counts;
  }
}
