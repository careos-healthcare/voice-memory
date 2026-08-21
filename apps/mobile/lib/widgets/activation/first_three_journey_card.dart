import 'package:archiveme_mobile/features/activation/first_three_journey_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/activation/first_three_session_journey_indicator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Warm activation card for the first three reflections journey.
class FirstThreeJourneyCard extends StatelessWidget {
  const FirstThreeJourneyCard({
    required this.model, super.key,
    this.compact = false,
    this.onCta,
  });

  final FirstThreeJourneyModel model;
  final bool compact;
  final VoidCallback? onCta;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;
  static const Color _stepActive = Color(0xFFE8A87C);
  static const Color _stepInactive = Color(0xFFE8DFD4);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('first_three_journey_payoff_card'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.28),
            blurRadius: compact ? 8 : 12,
            offset: Offset(0, compact ? 2 : 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FirstThreeSessionJourneyIndicator(
            activeStepIndex: model.journeyStepIndex,
            compact: compact,
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          if (!compact)
            Text(
              model.progressLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
          if (!compact) const SizedBox(height: AppSpacing.sm),
          _stepIndicator(),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          Text(
            model.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: compact ? 16 : 18,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              model.body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: VoiceMemoryColors.textSecondary,
              ),
            ),
          ],
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          const Text(
            ConsumerUiCopy.firstRecordPositioningLine,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: VoiceMemoryColors.textSecondary,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCta ?? () => _defaultCta(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
              ),
              child: Text(model.nextAction),
            ),
          ),
        ],
      ),
    );
  }

  void _defaultCta(BuildContext context) {
    if (model.completed) {
      context.go('/archive-belief');
    } else {
      context.go('/record');
    }
  }

  Widget _stepIndicator() {
    final filled = model.completedSteps;
    return Row(
      children: List.generate(3, (i) {
        final active = i < filled;
        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= filled ? _stepActive : _stepInactive,
                  ),
                ),
              Container(
                width: compact ? 10 : 12,
                height: compact ? 10 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? _stepActive : _stepInactive,
                  border: Border.all(
                    color: active ? _stepActive : _warmBorder,
                    width: 1.5,
                  ),
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < filled - 1 ? _stepActive : _stepInactive,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}