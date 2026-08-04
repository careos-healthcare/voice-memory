import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/first_60_second_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// A. First open / pre-record clarity — one short intro near the record
/// CTA, only for users with zero saved entries. It explains the start of
/// the loop in two lines and never blocks recording: the normal record
/// controls stay fully available below it.
class First60IntroCard extends StatelessWidget {
  const First60IntroCard({super.key, required this.onRecord});

  /// Starts the existing recording flow — never a new flow.
  final VoidCallback onRecord;

  /// Only for a completely empty archive.
  static bool shouldShow(int entryCount) =>
      First60Gates.showIntro(entryCount: entryCount);

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.first60IntroSeen,
      entryCount: 0,
      stage: First60Stage.intro.id,
      source: 'record',
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_60_intro_card'),
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
            First60Copy.introTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.introBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('first_60_record_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.first60RecordCtaTapped,
                entryCount: 0,
                stage: First60Stage.intro.id,
                source: 'record',
              );
              onRecord();
            },
            icon: const Icon(Icons.mic_none_outlined),
            label: const Text(First60Copy.introCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.introReassurance,
            textAlign: TextAlign.center,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
