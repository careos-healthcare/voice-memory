import 'package:archiveme_mobile/features/archive_milestone/archive_milestone_engine.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

class ArchiveLatestMilestoneMobile extends StatelessWidget {
  const ArchiveLatestMilestoneMobile({required this.milestone, super.key});

  final ArchiveMilestone milestone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VoiceMemoryColors.chapterBlue.withValues(alpha: 0.35),
        ),
        color: VoiceMemoryColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest milestone',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: VoiceMemoryColors.chapterBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            milestone.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: VoiceMemoryColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            milestone.explanation,
            style: const TextStyle(
              color: VoiceMemoryColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}