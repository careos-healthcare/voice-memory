import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/onboarding/first_60_second_state.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// C. Tomorrow return reason — shown after the first save.
///
/// The reminder CTA renders only when the existing reminder infrastructure
/// is available ([reminderAvailable]); notification permission is requested
/// by the coordinator behind [onRemind], and only after the user taps the
/// CTA. With no reminder path, accepting stores a local return cue only.
class First60ReturnCueCard extends StatelessWidget {
  const First60ReturnCueCard({
    required this.reminderAvailable, required this.onRemind, required this.onLocalCue, super.key,
  });

  /// True when the existing reminder offer is open for this user.
  final bool reminderAvailable;

  /// Schedules the one existing reminder — only ever called from the
  /// explicit "Remind me tomorrow" tap.
  final VoidCallback onRemind;

  /// Stores a local return cue only — no notifications involved.
  final VoidCallback onLocalCue;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.first60ReturnCueSeen,
      entryCount: 1,
      stage: First60Stage.returnCue.id,
      source: 'record',
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_60_return_cue_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFF8EE),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            First60Copy.returnTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.returnBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (reminderAvailable) ...[
            FilledButton.icon(
              key: const Key('first_60_remind_cta'),
              onPressed: () {
                ActivationFunnelAnalytics.track(
                  ActivationFunnelAnalytics.first60ReturnCueAccepted,
                  entryCount: 1,
                  stage: First60Stage.returnCue.id,
                  source: First60ReturnCueMethod.reminder,
                );
                onRemind();
              },
              icon: const Icon(Icons.schedule_outlined),
              label: const Text(First60Copy.returnRemindCta),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('first_60_local_cue_cta'),
              onPressed: _acceptLocalCue,
              child: const Text(First60Copy.returnLocalCta),
            ),
          ] else
            FilledButton.tonal(
              key: const Key('first_60_local_cue_cta'),
              onPressed: _acceptLocalCue,
              child: const Text(First60Copy.returnLocalCta),
            ),
        ],
      ),
    );
  }

  void _acceptLocalCue() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.first60ReturnCueAccepted,
      entryCount: 1,
      stage: First60Stage.returnCue.id,
      source: First60ReturnCueMethod.localCue,
    );
    onLocalCue();
  }
}