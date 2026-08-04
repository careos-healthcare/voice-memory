import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../services/app_services.dart';
import '../action_plan_engine.dart';
import '../action_plan_models.dart';
import 'micro_habit_card.dart';

typedef ActionPlansLoader = Future<List<ActionPlan>> Function();
typedef ActionPlanCheckIn =
    Future<ActionPlanCheckInResult> Function(String stepId, DateTime date);
typedef ActionPlanLifecycle = Future<ActionPlan> Function(String planId);

class ActionPlansOverlay extends StatefulWidget {
  const ActionPlansOverlay({
    super.key,
    this.load,
    this.checkIn,
    this.pause,
    this.resume,
    this.onClose,
    this.onShowOnGraph,
    this.onCheckInResult,
    this.onMilestone,
    this.now,
  });

  final ActionPlansLoader? load;
  final ActionPlanCheckIn? checkIn;
  final ActionPlanLifecycle? pause;
  final ActionPlanLifecycle? resume;
  final VoidCallback? onClose;
  final ValueChanged<String>? onShowOnGraph;
  final ValueChanged<ActionPlanCheckInResult>? onCheckInResult;
  final ValueChanged<ActionPlanCheckInResult>? onMilestone;
  final DateTime? now;

  static bool get hasDefaultServices => AppServices.isInitialized;

  @override
  State<ActionPlansOverlay> createState() => _ActionPlansOverlayState();
}

class _ActionPlansOverlayState extends State<ActionPlansOverlay> {
  late Future<List<ActionPlan>> _plans;
  String? _busyPlanId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _plans = _load();
  }

  Future<ActionPlanEngine> _engine() => _DefaultActionPlanEngine.get();

  Future<List<ActionPlan>> _load() async {
    final supplied = widget.load;
    if (supplied != null) return supplied();
    if (!ActionPlansOverlay.hasDefaultServices) {
      throw StateError('Action plan services are unavailable.');
    }
    return (await _engine()).list();
  }

  void _reload() {
    setState(() {
      _message = null;
      _plans = _load();
    });
  }

  Future<ActionPlanCheckInResult> _checkIn(MicroHabitStep step) async {
    try {
      final callback = widget.checkIn;
      final result = callback != null
          ? await callback(step.id, widget.now ?? DateTime.now())
          : await (await _engine()).checkIn(
              step.id,
              widget.now ?? DateTime.now(),
            );
      if (!mounted) return result;
      setState(() {
        _message = null;
        _plans = _plans.then(
          (plans) => [
            for (final plan in plans)
              if (plan.id == result.plan.id) result.plan else plan,
          ],
        );
      });
      widget.onCheckInResult?.call(result);
      if (result.milestoneReached != null) widget.onMilestone?.call(result);
      return result;
    } on Object {
      if (mounted) {
        setState(() => _message = 'Could not save that check-in. Try again.');
      }
      rethrow;
    }
  }

  Future<void> _changeLifecycle(ActionPlan plan) async {
    setState(() {
      _busyPlanId = plan.id;
      _message = null;
    });
    try {
      final pausing = plan.status == ActionPlanStatus.active;
      final callback = pausing ? widget.pause : widget.resume;
      final updated = callback != null
          ? await callback(plan.id)
          : pausing
          ? await (await _engine()).pause(plan.id)
          : await (await _engine()).resume(plan.id);
      if (!mounted) return;
      setState(() {
        _busyPlanId = null;
        _plans = _plans.then(
          (plans) => [
            for (final item in plans)
              if (item.id == updated.id) updated else item,
          ],
        );
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busyPlanId = null;
        _message = 'Could not update this plan. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      key: const Key('action-plans-overlay'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: .88),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Small steps',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const Text(
                              'Gentle actions connected to your graph',
                            ),
                          ],
                        ),
                      ),
                      if (widget.onClose != null)
                        IconButton(
                          key: const Key('action-plans-close'),
                          tooltip: 'Close small steps',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
                if (_message case final message?)
                  MaterialBanner(
                    content: Text(message),
                    actions: [
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(
                  child: FutureBuilder<List<ActionPlan>>(
                    future: _plans,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorState(onRetry: _reload);
                      }
                      final plans = snapshot.data;
                      if (plans == null) {
                        return const Center(
                          key: Key('action-plans-loading'),
                          child: CircularProgressIndicator(),
                        );
                      }
                      final visible = plans
                          .where(
                            (plan) =>
                                plan.status == ActionPlanStatus.active ||
                                plan.status == ActionPlanStatus.paused,
                          )
                          .toList();
                      if (visible.isEmpty) return const _EmptyState();
                      final active = visible
                          .where(
                            (plan) => plan.status == ActionPlanStatus.active,
                          )
                          .toList();
                      final paused = visible
                          .where(
                            (plan) => plan.status == ActionPlanStatus.paused,
                          )
                          .toList();
                      return ListView(
                        key: const Key('action-plans-list'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          if (active.isNotEmpty) ...[
                            const _SectionHeading('Active'),
                            for (final plan in active) _planCard(plan),
                          ],
                          if (paused.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const _SectionHeading('Paused'),
                            for (final plan in paused) _planCard(plan),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(ActionPlan plan) {
    final paused = plan.status == ActionPlanStatus.paused;
    return Card(
      key: Key('action-plan-${plan.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(plan.targetOutcome),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: Key('action-plan-lifecycle-${plan.id}'),
                  onPressed: _busyPlanId == plan.id
                      ? null
                      : () => _changeLifecycle(plan),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused ? 'Resume' : 'Pause'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final step in plan.steps) ...[
              MicroHabitCard(
                step: step,
                enabled: !paused,
                now: widget.now,
                onCheckIn: _checkIn,
                onShowOnGraph: widget.onShowOnGraph == null
                    ? null
                    : () => widget.onShowOnGraph!(step.targetNodeId),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    key: Key('action-plans-empty'),
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa_outlined, size: 44),
          SizedBox(height: 12),
          Text('No small steps yet.'),
          SizedBox(height: 5),
          Text(
            'Explore a cluster or a future path to shape one.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('action-plans-error'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.refresh_outlined, size: 40),
        const SizedBox(height: 10),
        const Text('Small steps could not be loaded.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('action-plans-retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

abstract final class _DefaultActionPlanEngine {
  static Future<ActionPlanEngine>? _future;

  static Future<ActionPlanEngine> get() =>
      _future ??= _create().catchError((Object error) {
        _future = null;
        throw error;
      });

  static Future<ActionPlanEngine> _create() async {
    if (!AppServices.isInitialized) {
      throw StateError('App services are not initialized.');
    }
    return AppServices.instance.actionPlanEngine;
  }
}
