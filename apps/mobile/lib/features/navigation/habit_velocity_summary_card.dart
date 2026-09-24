import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Archive summary that opens the habit velocity dashboard.
class HabitVelocitySummaryCard extends StatelessWidget {
  const HabitVelocitySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.neutral50,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        key: const Key('habit_velocity_summary_card'),
        title: const Text('Habit velocity and trends'),
        subtitle: const Text('Consistency, streaks, and logged moments'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(V1RouteRegistry.habitsPath),
      ),
    );
  }
}
