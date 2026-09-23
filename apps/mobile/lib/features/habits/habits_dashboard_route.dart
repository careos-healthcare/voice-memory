import 'dart:async';

import 'package:archiveme_mobile/features/habits/goal_velocity_calculator.dart';
import 'package:archiveme_mobile/features/habits/habit_tracker_service.dart';
import 'package:archiveme_mobile/features/habits/habits_dashboard_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Loads stored habits and opens [HabitsDashboardScreen].
class HabitsDashboardRoute extends StatefulWidget {
  const HabitsDashboardRoute({super.key});

  @override
  State<HabitsDashboardRoute> createState() => _HabitsDashboardRouteState();
}

class _HabitsDashboardRouteState extends State<HabitsDashboardRoute> {
  List<HabitDashboardCard> _cards = const [];
  HabitTrackerService? _tracker;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!AppServices.isInitialized) return;
    try {
      final tracker = HabitTrackerService(
        database: AppServices.instance.sqliteDatabase.database,
      );
      final habits = await tracker.listHabits();
      final now = DateTime.now();
      final cards = <HabitDashboardCard>[];
      for (final habit in habits) {
        final logs = await tracker.logsFor(habit.id);
        final report = GoalVelocityCalculator.report(
          habit: habit,
          logs: logs,
          sentimentByDay: const {},
          now: now,
        );
        cards.add(HabitDashboardCard(habit: habit, window: report.days30));
      }
      if (!mounted) return;
      setState(() {
        _tracker = tracker;
        _cards = cards;
      });
    } on Object {
      // A closed database leaves the dashboard empty.
    }
  }

  Future<void> _log() async {
    final tracker = _tracker;
    if (tracker == null || _cards.isEmpty) return;
    await tracker.logManual(_cards.first.habit.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return HabitsDashboardScreen(
      cards: _cards,
      onLogHabit: () => unawaited(_log()),
    );
  }
}
