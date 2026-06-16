import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_session/first_save_rescue.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// First Save Rescue — a tiny, low-stakes helper for users with zero
/// entries. One sentence to say, one CTA, and an explicit out ("You can
/// delete it after."). It sits alongside "How ArchiveMe works" and never
/// replaces or blocks the normal recording path.
class FirstSaveRescueCard extends StatelessWidget {
  const FirstSaveRescueCard({super.key, required this.onStart});

  /// Starts the existing recording flow — the rescue adds no new flow.
  final VoidCallback onStart;

  static const title = 'Try a 10-second test';
  static const body =
      'Say one sentence: \u201cWhat has been repeating lately?\u201d';
  static const reassurance = 'You can delete it after.';
  static const ctaLabel = 'Start test recording';

  /// Calm privacy/reversibility line — first-save confidence polish.
  static const confidenceLine =
      'This can be short, private, and deleted anytime.';

  /// Tiny helper rendered under the normal record CTA before the first save.
  static const oneSentenceLine = 'One sentence is enough.';

  /// Only for a completely empty archive; hides after the first save.
  static bool shouldShow(int entryCount) =>
      FirstSaveRescue.shouldShow(entryCount);

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstSaveRescueSeen,
      entryCount: 0,
      oncePerSession: true,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstSaveConfidenceSeen,
      entryCount: 0,
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_save_rescue_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F9F4),
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
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reassurance,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            confidenceLine,
            key: const Key('first_save_confidence_line'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('first_save_rescue_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.firstSaveRescueTapped,
                entryCount: 0,
              );
              FirstSaveRescue.startedFromRescueThisSession = true;
              onStart();
            },
            icon: const Icon(Icons.mic_none_outlined),
            label: const Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}
