import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/referral/invited_user_welcome.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Invited User Welcome — source-tailored framing for invited installs
/// before the first save. One CTA into the existing recording flow and a
/// clear "Not now". Replaces the generic first-session explainer for
/// invited users so the screen never gets more crowded.
class InvitedUserWelcomeCard extends StatelessWidget {
  const InvitedUserWelcomeCard({
    required this.source, required this.onRecord, required this.onDismiss, super.key,
  });

  /// Stable invite attribution source id; unknown values render the
  /// default copy.
  final String source;

  /// Starts the existing recording flow — never a new flow.
  final VoidCallback onRecord;

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.invitedUserWelcomeSeen,
      source: source,
      entryCount: 0,
      oncePerSession: true,
    );
    return Container(
      key: const Key('invited_user_welcome_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF2F7F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            InvitedUserWelcome.titleFor(source),
            key: const Key('invited_user_welcome_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            InvitedUserWelcome.bodyFor(source),
            key: const Key('invited_user_welcome_body'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('invited_user_welcome_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.invitedUserWelcomeTapped,
                source: source,
                entryCount: 0,
              );
              InvitedUserWelcome.startedFromWelcomeThisSession = true;
              InvitedUserWelcome.sessionSource = source;
              onRecord();
            },
            icon: const Icon(Icons.mic_none_outlined),
            label: const Text(InvitedUserWelcome.ctaLabel),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('invited_user_welcome_dismiss'),
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: const Text(InvitedUserWelcome.dismissLabel),
            ),
          ),
        ],
      ),
    );
  }
}