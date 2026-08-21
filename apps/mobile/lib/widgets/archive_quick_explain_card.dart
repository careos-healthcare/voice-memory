import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Compact archive stage hint — light card styling.
class ArchiveQuickExplainCard extends StatelessWidget {
  const ArchiveQuickExplainCard({required this.reflectionCount, super.key});

  final int reflectionCount;

  String get _stageLabel {
    if (reflectionCount <= 2) return 'Collecting evidence';
    if (reflectionCount <= 4) return 'Testing beliefs';
    return 'Tracking belief changes';
  }

  String get _stageRange {
    if (reflectionCount <= 2) return 'Reflection 1–2';
    if (reflectionCount <= 4) return 'Reflection 3–4';
    return 'Reflection 5+';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your archive is building a view of you.',
            style: VoiceMemoryTypography.bodyStyle(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Every reflection becomes evidence. Beliefs strengthen, weaken, or disappear.',
            style: VoiceMemoryTypography.metadataStyle(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Current stage: $_stageRange — $_stageLabel',
            style: VoiceMemoryTypography.metadataStyle(),
          ),
        ],
      ),
    );
  }
}