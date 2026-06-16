import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/belief_evolution/belief_evolution_models.dart';
import '../design/warm_archive_copy.dart';
import '../theme/app_theme.dart';

class BeliefEvolutionTimelineWidget extends StatelessWidget {
  const BeliefEvolutionTimelineWidget({super.key, required this.timeline});

  final BeliefEvolutionTimeline timeline;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const Text(
        'Pattern changes will appear here after you record a few more moments.',
        style: TextStyle(color: AppTheme.muted, height: 1.45),
      );
    }

    final blocks = timeline.blocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          _BeliefBlockView(block: blocks[i]),
          if (i < blocks.length - 1) ...[
            const _TimelineConnector(label: 'Changed into'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${blocks[i + 1].version.year}:\n"${blocks[i + 1].version.beliefText}"',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _BeliefBlockView extends StatelessWidget {
  const _BeliefBlockView({required this.block});

  final BeliefEvolutionBlock block;

  @override
  Widget build(BuildContext context) {
    final version = block.version;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(title: 'Pattern'),
        Text(
          '${version.year}:',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '"${version.beliefText}"',
          style: const TextStyle(
            color: AppTheme.foreground,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          WarmArchiveCopy.confidenceStrengthLine(version.confidence),
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        const _SectionLabel(title: 'Moments'),
        if (block.evidence.isEmpty)
          const Text(
            'No linked recordings yet.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          )
        else
          ...block.evidence.map((e) => _EvidenceTile(line: e)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.line});

  final BeliefEvidenceLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => context.push('/entry/${line.entryId}'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${line.quote}"',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  line.dateLabel,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          color: AppTheme.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppTheme.muted, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_downward,
              size: 16,
              color: AppTheme.muted.withValues(alpha: 0.8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppTheme.muted, height: 1)),
        ],
      ),
    );
  }
}
