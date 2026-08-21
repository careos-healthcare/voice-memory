import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Small first-session explainer shown on the Record screen for brand-new
/// users (no entries yet). It explains the core loop in three short steps
/// and gives the two existing ways to start — never a full onboarding
/// carousel, never blocking recording.
class FirstSessionExplanationCard extends StatelessWidget {
  const FirstSessionExplanationCard({
    required this.onLogPressure, required this.onRecord, super.key,
  });

  final VoidCallback onLogPressure;
  final VoidCallback onRecord;

  static const title = 'How ArchiveMe works';

  /// The core loop in three short steps — no claims beyond noticing.
  static const steps = [
    'Record one small thing.',
    'After a second moment, ArchiveMe can start comparing your own words.',
    'Tomorrow, check whether it returned, faded, or changed.',
  ];

  static const footer = 'That is enough for today.';
  static const primaryLabel = 'Log pressure moment';
  static const secondaryLabel = 'Record a thought';

  /// Show only for brand-new users — no pressure check-ins / no entries yet.
  /// Pressure check-ins are saved as journal entries, so a single entry count
  /// covers both. Hides after the first successful save.
  static bool shouldShow(int entryCount) => entryCount == 0;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstSessionCardSeen,
      entryCount: 0,
      oncePerSession: true,
    );
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
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: ArchiveMobileTypography.body(context).copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: ArchiveMobileTypography.body(
                        context,
                      ).copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            footer,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
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