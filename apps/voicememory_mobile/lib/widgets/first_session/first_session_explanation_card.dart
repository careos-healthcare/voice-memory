import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Small first-session explainer shown on the Record screen for brand-new
/// users (no entries yet). It tells them what ArchiveMe is for and gives them
/// the two ways to start — without becoming a full onboarding carousel.
class FirstSessionExplanationCard extends StatelessWidget {
  const FirstSessionExplanationCard({
    super.key,
    required this.onLogPressure,
    required this.onRecord,
  });

  final VoidCallback onLogPressure;
  final VoidCallback onRecord;

  static const title = 'Catch the moment pressure takes over';
  static const body =
      "Use ArchiveMe when you're doing more because stopping makes you feel "
      'behind.';
  static const primaryLabel = 'Log pressure moment';
  static const secondaryLabel = 'Record a thought';

  /// Show only for brand-new users — no pressure check-ins / no entries yet.
  /// Pressure check-ins are saved as journal entries, so a single entry count
  /// covers both. Hides once the user logs anything.
  static bool shouldShow(int entryCount) => entryCount == 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('first_session_explanation_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('first_session_log_pressure_cta'),
            onPressed: onLogPressure,
            icon: const Icon(Icons.bolt_outlined),
            label: const Text(primaryLabel),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('first_session_record_cta'),
            onPressed: onRecord,
            child: const Text(secondaryLabel),
          ),
        ],
      ),
    );
  }
}
