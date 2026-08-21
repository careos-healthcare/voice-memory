import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Post check-in card offering the one simple next thing to check tomorrow.
class PatternNextActionCard extends StatefulWidget {
  const PatternNextActionCard({required this.action, super.key, this.onUse});

  final PatternNextAction action;

  /// Creates/uses tomorrow's check-in with [action.question].
  final VoidCallback? onUse;

  static const String title = 'Next useful check';

  static const Color _surface = Color(0xFFEAF3EE);
  static const Color _border = Color(0xFFCDE3D6);

  @override
  State<PatternNextActionCard> createState() => _PatternNextActionCardState();
}

class _PatternNextActionCardState extends State<PatternNextActionCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackPatternNextActionShown();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: PatternNextActionCard._surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PatternNextActionCard._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PatternNextActionCard.title,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            action.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            action.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            action.question,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (widget.onUse != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: widget.onUse,
                child: Text(action.ctaLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}