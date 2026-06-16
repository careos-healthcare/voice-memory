import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/record_return_pro_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// C. Return tomorrow cue — reminder CTA when infrastructure exists;
/// local intent otherwise. Permission only after an explicit reminder tap.
class TomorrowReturnCueCard extends StatelessWidget {
  const TomorrowReturnCueCard({
    super.key,
    required this.reminderAvailable,
    required this.onLocalCue,
    required this.onRemind,
  });

  final bool reminderAvailable;
  final VoidCallback onLocalCue;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.returnTomorrowSeen,
      entryCount: 1,
      stage: RecordReturnProStage.returnCue.id,
      source: 'record',
      oncePerSession: true,
    );
    return Container(
      key: const Key('tomorrow_return_cue_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFF8EE),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RecordReturnProCopy.returnTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.returnBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (reminderAvailable)
            FilledButton.icon(
              key: const Key('tomorrow_return_remind_cta'),
              onPressed: _acceptReminder,
              icon: const Icon(Icons.schedule_outlined),
              label: const Text(RecordReturnProCopy.returnRemindCta),
            )
          else
            FilledButton(
              key: const Key('tomorrow_return_local_cta'),
              onPressed: _acceptLocalCue,
              child: const Text(RecordReturnProCopy.returnLocalCta),
            ),
          if (reminderAvailable) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _acceptLocalCue,
              child: const Text(RecordReturnProCopy.returnLocalCta),
            ),
          ],
        ],
      ),
    );
  }

  void _acceptReminder() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.returnTomorrowAccepted,
      entryCount: 1,
      stage: RecordReturnProStage.returnCue.id,
      source: RecordReturnProReturnCueMethod.reminder,
    );
    onRemind();
  }

  void _acceptLocalCue() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.returnTomorrowAccepted,
      entryCount: 1,
      stage: RecordReturnProStage.returnCue.id,
      source: RecordReturnProReturnCueMethod.localCue,
    );
    onLocalCue();
  }
}
