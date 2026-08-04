import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_value/archive_value_progress.dart';
import '../models/journal_entry.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

class ArchiveValueBanner extends StatelessWidget {
  const ArchiveValueBanner({
    super.key,
    required this.entries,
    this.compact = false,
  });

  final List<JournalEntry> entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final snapshot = ArchiveValueProgress.build(entries);
    if (snapshot.reflectionCount < 1) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 8 : 16),
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.2),
        ),
        color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Archive value',
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.primaryIndigo,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.valueCopy,
            style: VoiceMemoryTypography.cardTitleStyle(),
          ),
          const SizedBox(height: 6),
          Text(
            '${snapshot.reflectionCount.clamp(0, ArchiveValueProgress.target)}/${ArchiveValueProgress.target} moments toward pattern review · ${snapshot.progressPercent}%',
            style: VoiceMemoryTypography.secondaryStyle(),
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.nextMilestoneCopy,
            style: VoiceMemoryTypography.secondaryStyle(),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go(snapshot.ctaRoute),
            child: Text(snapshot.ctaLabel),
          ),
        ],
      ),
    );
  }
}
