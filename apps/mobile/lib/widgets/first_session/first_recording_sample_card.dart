import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_session/first_recording_sample.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// First Recording Sample — one starter sentence and a single CTA for
/// zero-entry users. Sits in the first-session area near First Save Rescue
/// and never replaces or blocks the normal recording path.
class FirstRecordingSampleCard extends StatelessWidget {
  const FirstRecordingSampleCard({required this.onUseStarter, super.key});

  /// Seeds the existing recording flow with the sample line — no new flow.
  final VoidCallback onUseStarter;

  /// Only for a completely empty archive; hides after the first save.
  static bool shouldShow(int entryCount) =>
      FirstRecordingSample.shouldShow(entryCount);

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstRecordingSampleSeen,
      entryCount: 0,
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_recording_sample_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF5F7FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FirstRecordingSample.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '\u201c${FirstRecordingSample.sample}\u201d',
            key: const Key('first_recording_sample_line'),
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            FirstRecordingSample.helper,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('first_recording_sample_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.firstRecordingSampleTapped,
                entryCount: 0,
              );
              FirstRecordingSample.startedFromSampleThisSession = true;
              onUseStarter();
            },
            icon: const Icon(Icons.mic_none_outlined),
            label: const Text(FirstRecordingSample.ctaLabel),
          ),
        ],
      ),
    );
  }
}