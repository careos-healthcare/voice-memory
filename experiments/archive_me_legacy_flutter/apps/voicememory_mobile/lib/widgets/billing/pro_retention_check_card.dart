import 'package:flutter/material.dart';

import '../../billing/pro_retention_check.dart';
import '../../design/archive_mobile_typography.dart';
import '../../features/referral/referral_invite_after_value.dart';
import '../../features/review/review_prompt_after_value.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// One optional question for Pro users — two equal-weight taps, no text
/// input, and a calm acknowledgement either way. Never part of any
/// cancellation flow.
class ProRetentionCheckCard extends StatefulWidget {
  const ProRetentionCheckCard({
    super.key,
    required this.cardType,
    this.entryCount = 0,
    this.hasConnectedThread = false,
  });

  /// Stable id of the Pro-value surface that made the check eligible.
  final String cardType;

  final int entryCount;

  /// From the existing thread evidence engine — analytics context only.
  final bool hasConnectedThread;

  @override
  State<ProRetentionCheckCard> createState() => _ProRetentionCheckCardState();
}

class _ProRetentionCheckCardState extends State<ProRetentionCheckCard> {
  String? _ack;

  void _answer({required bool useful}) {
    // A Pro "yes" is a value signal the referral invite and the review
    // prompt may follow.
    if (useful) {
      ReferralInviteAfterValue.recordProRetentionYes();
      ReviewPromptAfterValue.recordProRetentionYes();
    }
    ActivationFunnelAnalytics.track(
      useful
          ? ActivationFunnelAnalytics.proRetentionCheckYes
          : ActivationFunnelAnalytics.proRetentionCheckNotYet,
      cardType: widget.cardType,
      entryCount: widget.entryCount,
      hasConnectedThread: widget.hasConnectedThread,
    );
    setState(() {
      _ack = useful ? ProRetentionCheck.yesAck : ProRetentionCheck.notYetAck;
    });
  }

  @override
  Widget build(BuildContext context) {
    ProRetentionCheck.shownThisSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.proRetentionCheckSeen,
      cardType: widget.cardType,
      entryCount: widget.entryCount,
      hasConnectedThread: widget.hasConnectedThread,
      oncePerSession: true,
    );

    return Container(
      key: const Key('pro_retention_check_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F6F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProRetentionCheck.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_ack != null)
            Text(
              _ack!,
              key: const Key('pro_retention_check_ack'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            )
          else ...[
            Text(
              ProRetentionCheck.question,
              style: ArchiveMobileTypography.body(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                // Two equal-weight options — neither answer is steered.
                Expanded(
                  child: OutlinedButton(
                    key: const Key('pro_retention_check_yes'),
                    onPressed: () => _answer(useful: true),
                    child: const Text(ProRetentionCheck.yesLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('pro_retention_check_not_yet'),
                    onPressed: () => _answer(useful: false),
                    child: const Text(
                      ProRetentionCheck.notYetLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
