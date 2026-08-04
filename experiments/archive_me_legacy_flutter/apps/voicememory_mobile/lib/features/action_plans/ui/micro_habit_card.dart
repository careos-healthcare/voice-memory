import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../action_plan_models.dart';

typedef MicroHabitCheckIn =
    Future<ActionPlanCheckInResult> Function(MicroHabitStep step);

class MicroHabitCard extends StatefulWidget {
  const MicroHabitCard({
    super.key,
    required this.step,
    required this.enabled,
    required this.onCheckIn,
    this.now,
    this.onShowOnGraph,
    this.onCompleted,
  });

  final MicroHabitStep step;
  final bool enabled;
  final MicroHabitCheckIn onCheckIn;
  final DateTime? now;
  final VoidCallback? onShowOnGraph;
  final ValueChanged<ActionPlanCheckInResult>? onCompleted;

  @override
  State<MicroHabitCard> createState() => _MicroHabitCardState();
}

class _MicroHabitCardState extends State<MicroHabitCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  var _checking = false;
  ActionPlanCheckInResult? _latestResult;

  DateTime get _today => widget.now ?? DateTime.now();

  bool get _completedToday {
    final result = _latestResult;
    if (result != null) {
      return result.step.completionHistory[canonicalActionPlanDate(_today)] ==
          true;
    }
    return widget.step.completionHistory[canonicalActionPlanDate(_today)] ==
        true;
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    if (_checking || _completedToday || !widget.enabled) return;
    setState(() => _checking = true);
    try {
      final result = await widget.onCheckIn(widget.step);
      if (!mounted) return;
      setState(() {
        _latestResult = result;
        _checking = false;
      });
      if (!result.alreadyCheckedIn) {
        if (result.milestoneReached case final int _) {
          unawaited(HapticFeedback.mediumImpact());
        } else {
          unawaited(HapticFeedback.selectionClick());
        }
        final media = MediaQuery.of(context);
        if (!media.disableAnimations && !media.accessibleNavigation) {
          unawaited(_glow.forward(from: 0).then((_) => _glow.reverse()));
        }
        widget.onCompleted?.call(result);
      }
    } on Object {
      if (mounted) setState(() => _checking = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = _completedToday;
    final step = _latestResult?.step ?? widget.step;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (_glow.value > 0)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(
                  alpha: .28 * _glow.value,
                ),
                blurRadius: 22 * _glow.value,
                spreadRadius: 2 * _glow.value,
              ),
          ],
        ),
        child: child,
      ),
      child: Card(
        key: Key('micro-habit-${widget.step.id}'),
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: completed
                ? theme.colorScheme.primary.withValues(alpha: .58)
                : theme.colorScheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                checked: completed,
                enabled: widget.enabled && !completed,
                label: completed
                    ? '${step.title}, completed today'
                    : 'Complete ${step.title}',
                child: SizedBox.square(
                  dimension: 48,
                  child: IconButton.filledTonal(
                    key: Key('micro-habit-check-${step.id}'),
                    tooltip: completed ? 'Completed today' : 'Complete today',
                    onPressed: widget.enabled && !completed && !_checking
                        ? _checkIn
                        : null,
                    icon: _checking
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        Text(_scheduleText(step.frequency)),
                        Text(
                          '${step.streakCount} ${step.streakCount == 1 ? 'day' : 'days'} in a row',
                          key: Key('micro-habit-days-${step.id}'),
                        ),
                      ],
                    ),
                    if (widget.onShowOnGraph != null)
                      TextButton.icon(
                        key: Key('micro-habit-graph-${step.id}'),
                        onPressed: widget.onShowOnGraph,
                        icon: const Icon(Icons.hub_outlined, size: 18),
                        label: const Text('Show on graph'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _scheduleText(ActionPlanFrequency frequency) {
  if (frequency.type == ActionPlanFrequencyType.daily) return 'Every day';
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final days = frequency.weekdays.toList()..sort();
  return days.map((day) => labels[day - 1]).join(', ');
}
