import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Trial-only guidance shown before the first reflection is saved.
class TrialFirstMomentCard extends StatelessWidget {
  const TrialFirstMomentCard({required this.onStartRecording, super.key});

  final VoidCallback onStartRecording;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  static const _bullets = [
    'Say what happened.',
    'Say how it felt.',
    'Do not make it perfect.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try this once',
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Record one ordinary moment from today. Tomorrow, ArchiveMe will ask if the pattern showed up again.',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in _bullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 14, height: 1.45),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 14, height: 1.45),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () {
                unawaited(ActivationTracker.trackTrialRecordCtaTapped());
                onStartRecording();
              },
              child: const Text('Start recording'),
            ),
          ),
        ],
      ),
    );
  }
}