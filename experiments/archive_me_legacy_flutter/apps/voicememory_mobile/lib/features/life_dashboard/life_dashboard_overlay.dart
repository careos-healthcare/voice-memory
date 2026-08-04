import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/hallucination_guard/hallucination_guard_service.dart';
import '../../shared/ui/ai_explainability_card.dart';
import 'life_dashboard_models.dart';

typedef LifeDashboardLoader =
    Future<LifeDashboardSnapshot> Function(TimeHorizon horizon);

class LifeDashboardOverlay extends StatefulWidget {
  const LifeDashboardOverlay({
    super.key,
    required this.load,
    required this.onHighlightNodes,
    this.hallucinationGuard,
  });

  final LifeDashboardLoader load;
  final ValueChanged<Set<String>> onHighlightNodes;
  final HallucinationGuardService? hallucinationGuard;

  @override
  State<LifeDashboardOverlay> createState() => _LifeDashboardOverlayState();
}

class _LifeDashboardOverlayState extends State<LifeDashboardOverlay> {
  var _horizon = TimeHorizon.today;
  late Future<LifeDashboardSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.load(_horizon);
  }

  void _selectHorizon(TimeHorizon horizon) {
    if (horizon == _horizon) return;
    setState(() {
      _horizon = horizon;
      _snapshot = widget.load(horizon);
    });
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Material(
        key: const Key('life_dashboard_overlay'),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              'Life Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            TemporalHorizonSelector(
              selected: _horizon,
              onSelected: _selectHorizon,
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<LifeDashboardSnapshot>(
                future: _snapshot,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Dashboard insights are temporarily unavailable.',
                      ),
                    );
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    child: _DashboardSections(
                      key: ValueKey(data.horizon),
                      snapshot: data,
                      onHighlightNodes: widget.onHighlightNodes,
                      hallucinationGuard: widget.hallucinationGuard,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TemporalHorizonSelector extends StatelessWidget {
  const TemporalHorizonSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TimeHorizon selected;
  final ValueChanged<TimeHorizon> onSelected;

  @override
  Widget build(BuildContext context) => SegmentedButton<TimeHorizon>(
    key: const Key('temporal_horizon_selector'),
    segments: [
      for (final horizon in TimeHorizon.values)
        ButtonSegment(value: horizon, label: Text(horizon.label)),
    ],
    selected: {selected},
    showSelectedIcon: false,
    onSelectionChanged: (selection) => onSelected(selection.single),
  );
}

class _DashboardSections extends StatelessWidget {
  const _DashboardSections({
    super.key,
    required this.snapshot,
    required this.onHighlightNodes,
    required this.hallucinationGuard,
  });

  final LifeDashboardSnapshot snapshot;
  final ValueChanged<Set<String>> onHighlightNodes;
  final HallucinationGuardService? hallucinationGuard;

  @override
  Widget build(BuildContext context) => ListView(
    key: Key('dashboard_sections_${snapshot.horizon.name}'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: [
      _LensCard(
        key: const Key('dashboard_daily_pulse_card'),
        title: 'Local pulse',
        icon: Icons.bolt,
        children: [
          Text(
            '${snapshot.localSemanticMatches} local matches · '
            'emotional velocity '
            '${snapshot.dailyPulse.emotionalVelocity.toStringAsFixed(2)}',
          ),
          _items(
            snapshot.dailyPulse.immediateActionItems,
            empty: 'No immediate action items detected.',
          ),
        ],
      ),
      _LensCard(
        key: const Key('dashboard_identity_card'),
        title: 'Identity',
        icon: Icons.fingerprint,
        onTap: snapshot.identity.nodeIds.isEmpty
            ? null
            : () => onHighlightNodes(snapshot.identity.nodeIds),
        children: [
          _items(
            snapshot.identity.coreBeliefs,
            empty: 'No identity evidence in this horizon.',
          ),
          _items(snapshot.identity.selfPerceptionShifts),
          if (snapshot.identity.explainability case final explainability?)
            AiExplainabilityCard(
              explainability: explainability,
              hallucinationGuard: hallucinationGuard,
            ),
        ],
      ),
      _LensCard(
        key: const Key('dashboard_habits_card'),
        title: 'Habits',
        icon: Icons.repeat,
        children: [
          for (final habit in snapshot.habits)
            ListTile(
              title: Text(habit.label),
              subtitle: Text(
                '${habit.mentionCount} mentions · '
                '${habit.consistencyVelocity >= 0 ? 'building' : 'slowing'}',
              ),
              onTap: () => onHighlightNodes({habit.nodeId}),
            ),
          if (snapshot.habits.isEmpty)
            const Text('No active habits in this horizon.'),
        ],
      ),
      _LensCard(
        key: const Key('dashboard_relationships_card'),
        title: 'Relationships',
        icon: Icons.people_outline,
        children: [
          for (final relationship in snapshot.relationships)
            ListTile(
              title: Text(relationship.personLabel),
              subtitle: Text(
                '${relationship.recentTouchpoints} touchpoints · '
                'valence ${relationship.valenceTrend.toStringAsFixed(2)}',
              ),
              onTap: () => onHighlightNodes({relationship.personNodeId}),
            ),
          if (snapshot.relationships.isEmpty)
            const Text('No relationship touchpoints in this horizon.'),
        ],
      ),
      _LensCard(
        key: const Key('dashboard_goals_card'),
        title: 'Goals',
        icon: Icons.flag_outlined,
        children: [
          for (final goal in snapshot.goals) ...[
            ListTile(
              title: Text(goal.label),
              subtitle: Text(
                '${goal.statedIntentions} intentions · '
                '${goal.actualMentions} action mentions',
              ),
              onTap: () => onHighlightNodes({goal.nodeId}),
            ),
            if (goal.explainability case final explainability?)
              AiExplainabilityCard(
                explainability: explainability,
                hallucinationGuard: hallucinationGuard,
              ),
          ],
          if (snapshot.goals.isEmpty)
            const Text('No active goals in this horizon.'),
        ],
      ),
      _LensCard(
        key: const Key('dashboard_predictions_card'),
        title: 'Predictions',
        icon: Icons.auto_graph,
        children: [
          for (final prediction in snapshot.predictions) ...[
            ListTile(
              title: Text(prediction.statement),
              subtitle: Text(
                '${prediction.category} · '
                '${(prediction.probability * 100).round()}%',
              ),
              onTap: () => onHighlightNodes({prediction.nodeId}),
            ),
            AiExplainabilityCard(
              explainability: prediction.explainability,
              hallucinationGuard: hallucinationGuard,
            ),
          ],
          if (snapshot.predictions.isEmpty)
            const Text('No evidence-backed forecast for this horizon.'),
        ],
      ),
    ],
  );

  static Widget _items(List<String> values, {String? empty}) {
    if (values.isEmpty) return Text(empty ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final value in values) Text('• $value')],
    );
  }
}

class _LensCard extends StatelessWidget {
  const _LensCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainer.withValues(alpha: .72),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    ),
  );
}
