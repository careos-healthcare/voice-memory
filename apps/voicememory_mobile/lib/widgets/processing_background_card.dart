import 'package:flutter/material.dart';

import '../product/consumer_ui_copy.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Shown while capture pipeline runs — user can leave the Record tab.
class ProcessingBackgroundCard extends StatelessWidget {
  const ProcessingBackgroundCard({
    super.key,
    required this.stageLabel,
    this.progress,
  });

  final String stageLabel;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Processing reflection',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Processing in background',
              style: VoiceMemoryTypography.cardTitleStyle(),
            ),
            const SizedBox(height: 8),
            Text(
              stageLabel.isNotEmpty ? stageLabel : 'Saving your reflection…',
              style: VoiceMemoryTypography.bodyStyle(
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You can switch tabs or record again when ready. '
              '${ConsumerUiCopy.processingReflectionSaved}',
              style: VoiceMemoryTypography.secondaryStyle(),
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                color: VoiceMemoryColors.primaryIndigo,
                backgroundColor: VoiceMemoryColors.surfaceSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
