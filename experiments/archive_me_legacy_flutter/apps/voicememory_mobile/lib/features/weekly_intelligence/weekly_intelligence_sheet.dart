import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/hallucination_guard/hallucination_guard_service.dart';
import '../../shared/ui/ai_explainability_card.dart';
import '../../shared/ui/citation_playback_widget.dart';
import 'weekly_intelligence_models.dart';

typedef WeeklyIntelligenceLoader =
    Future<WeeklyIntelligenceSnapshot> Function();

class WeeklyIntelligenceSheet extends StatefulWidget {
  const WeeklyIntelligenceSheet({
    super.key,
    required this.load,
    required this.onHighlightNodes,
    this.hallucinationGuard,
    this.onPlaybackIntent,
  });

  final WeeklyIntelligenceLoader load;
  final ValueChanged<Set<String>> onHighlightNodes;
  final HallucinationGuardService? hallucinationGuard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;

  @override
  State<WeeklyIntelligenceSheet> createState() =>
      _WeeklyIntelligenceSheetState();
}

class _WeeklyIntelligenceSheetState extends State<WeeklyIntelligenceSheet> {
  late Future<WeeklyIntelligenceSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.load();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Material(
        key: const Key('weekly_intelligence_sheet'),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .93),
        child: FutureBuilder<WeeklyIntelligenceSnapshot>(
          future: _snapshot,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  title: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What Changed This Week'),
                      Text(
                        'Sunday Behavioral Intelligence',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Close weekly intelligence',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (snapshot.hasError)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Your local weekly intelligence is temporarily unavailable.',
                      ),
                    ),
                  )
                else if (data == null)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (data.deltas.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Keep recording intentions and actions to reveal a '
                          'week-over-week behavioral change.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    sliver: SliverList.builder(
                      itemCount: data.deltas.length,
                      itemBuilder: (context, index) => _BehavioralDeltaCard(
                        delta: data.deltas[index],
                        hallucinationGuard: widget.hallucinationGuard,
                        onPlaybackIntent: widget.onPlaybackIntent,
                        onTap: () =>
                            widget.onHighlightNodes(data.deltas[index].nodeIds),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _BehavioralDeltaCard extends StatelessWidget {
  const _BehavioralDeltaCard({
    required this.delta,
    required this.onTap,
    required this.hallucinationGuard,
    required this.onPlaybackIntent,
  });

  final BehavioralDelta delta;
  final VoidCallback onTap;
  final HallucinationGuardService? hallucinationGuard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('weekly_delta_${delta.id}'),
    margin: const EdgeInsets.only(bottom: 14),
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainer.withValues(alpha: .78),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(_icon(delta.dimension)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delta.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(delta.statement),
                      ],
                    ),
                  ),
                  Text(
                    _magnitude(delta.magnitude),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          AiExplainabilityCard(
            explainability: delta.explainability,
            hallucinationGuard: hallucinationGuard,
            onPlaybackIntent: onPlaybackIntent,
          ),
        ],
      ),
    ),
  );

  static IconData _icon(BehavioralDeltaDimension dimension) =>
      switch (dimension) {
        BehavioralDeltaDimension.actionIntentRatio => Icons.task_alt,
        BehavioralDeltaDimension.emotionalVelocity => Icons.trending_up,
        BehavioralDeltaDimension.habitDrift => Icons.repeat,
        BehavioralDeltaDimension.relationshipDynamics => Icons.people_outline,
        BehavioralDeltaDimension.identityShift => Icons.fingerprint,
      };

  static String _magnitude(double value) {
    if (value.abs() < .01) return 'steady';
    return '${value > 0 ? '+' : ''}${(value * 100).round()}%';
  }
}
