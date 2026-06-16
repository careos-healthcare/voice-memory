import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_growth/archive_growth_copy.dart';
import '../../features/archive_growth/archive_journey_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';

/// Prominent archive journey progress on archive home.
class ArchiveJourneyBanner extends StatelessWidget {
  const ArchiveJourneyBanner({super.key, required this.journey});

  final ArchiveJourneyView journey;

  @override
  Widget build(BuildContext context) {
    final total = journey.steps.length;
    final done = journey.completedCount;
    ArchiveJourneyStep? next;
    for (final s in journey.steps) {
      if (s.isUnlocked && !s.isComplete) {
        next = s;
        break;
      }
    }

    return Material(
      color: VoiceMemoryColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/archive-journey'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ArchiveJourneyCopy.journeyTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$done / $total',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppTheme.muted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  backgroundColor: VoiceMemoryColors.border,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 10),
                Text(
                  next.isUnlocked && next.reward.isNotEmpty
                      ? next.reward
                      : next.instruction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
