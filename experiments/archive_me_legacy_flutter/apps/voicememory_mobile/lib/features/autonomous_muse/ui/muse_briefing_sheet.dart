import 'package:flutter/material.dart';

import '../../../shared/ui/glassmorphic_container.dart';
import '../autonomous_muse_models.dart';

final class MuseBriefingSheet extends StatelessWidget {
  const MuseBriefingSheet({
    super.key,
    required this.briefing,
    required this.onClose,
    this.onOpenNode,
    this.onOpenActionPlan,
  });

  final MuseBriefing briefing;
  final VoidCallback onClose;
  final ValueChanged<String>? onOpenNode;
  final ValueChanged<String>? onOpenActionPlan;

  @override
  Widget build(BuildContext context) {
    final serendipity =
        briefing.serendipity ?? briefing.discoveries.firstOrNull;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassmorphicContainer(
            key: const Key('muse-briefing-sheet'),
            radius: BorderRadius.circular(32),
            blurSigma: 22,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF9DE7FF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The Autonomous Muse',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      key: const Key('muse-briefing-close'),
                      tooltip: 'Close Muse briefing',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Created overnight on this device. Nothing left your vault.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Text(
                  'Serendipity Discovery',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF9DE7FF),
                  ),
                ),
                const SizedBox(height: 10),
                if (serendipity == null)
                  Text(briefing.summary)
                else
                  _DiscoveryCard(
                    discovery: serendipity,
                    summary: briefing.summary,
                    onOpenNode: onOpenNode,
                  ),
                const Spacer(),
                if (briefing.actionPrompt case final prompt?)
                  GlassmorphicContainer(
                    key: const Key('muse-action-revival'),
                    radius: BorderRadius.circular(20),
                    blurSigma: 10,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('A dormant intention worth reviving'),
                        const SizedBox(height: 8),
                        Text(prompt),
                        if (briefing.actionPlanId case final planId?)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: const Key('muse-open-action-plan'),
                              onPressed: onOpenActionPlan == null
                                  ? null
                                  : () => onOpenActionPlan!(planId),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Open plan'),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.discovery,
    required this.summary,
    required this.onOpenNode,
  });

  final MuseBridgeDiscovery discovery;
  final String summary;
  final ValueChanged<String>? onOpenNode;

  @override
  Widget build(BuildContext context) => GlassmorphicContainer(
    radius: BorderRadius.circular(24),
    blurSigma: 14,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              key: const Key('muse-source-memory'),
              avatar: Text('${discovery.sourceYear}'),
              label: Text(discovery.sourceLabel),
              onPressed: onOpenNode == null
                  ? null
                  : () => onOpenNode!(discovery.sourceNodeId),
            ),
            const Icon(Icons.more_horiz),
            ActionChip(
              key: const Key('muse-target-memory'),
              avatar: Text('${discovery.targetYear}'),
              label: Text(discovery.targetLabel),
              onPressed: onOpenNode == null
                  ? null
                  : () => onOpenNode!(discovery.targetNodeId),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(summary),
        const SizedBox(height: 12),
        Text(
          '${(discovery.similarity * 100).round()}% local semantic overlap',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}
