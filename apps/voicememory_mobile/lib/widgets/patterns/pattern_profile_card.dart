import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activation/activation_tracker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Compact entry into the unified pattern profile on the Patterns tab.
class PatternProfileCard extends StatefulWidget {
  const PatternProfileCard({super.key});

  @override
  State<PatternProfileCard> createState() => _PatternProfileCardState();
}

class _PatternProfileCardState extends State<PatternProfileCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackPatternProfileShown();
  }

  void _open() {
    context.push('/pattern-profile');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warmBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 22, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pattern profile',
                  style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'See this pattern in one place.',
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _open, child: const Text('Open profile')),
        ],
      ),
    );
  }
}
