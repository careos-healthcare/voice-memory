import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact Record-screen reminder shown once the return trigger is accepted.
/// Sits alongside the capture actions — it never replaces the first-session
/// card and is only a quiet pointer back to the pressure check-in.
class PressureReturnTriggerReminder extends StatelessWidget {
  const PressureReturnTriggerReminder({
    super.key,
    required this.onLogPressure,
  });

  final VoidCallback onLogPressure;

  static const title = 'Catch it before you push through.';
  static const subcopy = 'Log the pressure moment before it becomes proof.';
  static const ctaLabel = 'Log pressure moment';

  /// Show only when the trigger is accepted and the user is past their first
  /// session (the first-session card owns the brand-new-user moment).
  static bool shouldShow({
    required bool accepted,
    required int entryCount,
  }) =>
      accepted && entryCount > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_return_trigger_reminder'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(
        background: const Color(0xFFF0F6FF),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_outlined,
            size: 18,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ArchiveMobileTypography.body(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subcopy,
                  style:
                      ArchiveMobileTypography.responsiveHelper(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            key: const Key('pressure_return_trigger_reminder_cta'),
            onPressed: onLogPressure,
            child: const Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}
