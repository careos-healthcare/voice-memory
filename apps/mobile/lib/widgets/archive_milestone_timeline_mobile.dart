import 'package:archiveme_mobile/features/archive_milestone/archive_milestone_engine.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

class ArchiveMilestoneTimelineMobile extends StatelessWidget {
  const ArchiveMilestoneTimelineMobile({
    required this.milestones, super.key,
    this.emptyMessage,
  });

  final List<ArchiveMilestone> milestones;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      if (emptyMessage == null) return const SizedBox.shrink();
      return Text(
        emptyMessage!,
        style: const TextStyle(color: AppTheme.muted, height: 1.45),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Archive History',
          style: VoiceMemoryTypography.sectionLabelStyle(
            
          ),
        ),
        const SizedBox(height: 12),
        ...milestones.reversed.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  height: 48,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  color: AppTheme.accent,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.periodLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.explanation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}