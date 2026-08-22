import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Home hero — your archive at a glance with large stat numbers.
class ArchiveHomeHeaderCard extends StatelessWidget {
  const ArchiveHomeHeaderCard({
    required this.recordings, required this.beliefs, required this.insights, super.key,
  });

  final int recordings;
  final int beliefs;
  final int insights;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Archive', style: VoiceMemoryTypography.headlineStyle()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Building evidence about who you are becoming.',
            style: VoiceMemoryTypography.metadataStyle(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatColumn(label: 'Recordings', value: recordings),
              ),
              Expanded(
                child: _StatColumn(label: 'Beliefs', value: beliefs),
              ),
              Expanded(
                child: _StatColumn(label: 'Insights', value: insights),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: VoiceMemoryTypography.headlineStyle(
            color: AppColors.accentPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: VoiceMemoryTypography.metadataStyle()),
      ],
    );
  }
}