import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_evidence/archive_belief_thread_copy.dart';
import '../../features/archive_evidence/archive_belief_thread_model.dart';
import '../../theme/app_spacing.dart';

/// Simple vertical timeline for a repeated thread.
class ArchiveEvidenceTimeline extends StatelessWidget {
  const ArchiveEvidenceTimeline({super.key, required this.steps});

  final List<ArchiveEvidenceTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ArchiveBeliefThreadCopy.timelineTitle,
          key: const Key('archive_evidence_timeline_title'),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: Color(0xFF6B8F71),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].label,
                      style: ArchiveMobileTypography.cardLabel(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      steps[i].body,
                      style: ArchiveMobileTypography.body(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i < steps.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
