import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/referral/referral_invite_after_value.dart';
import '../../features/review/review_prompt_after_value.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Hosts the referral invite below the value-moment cards. Re-evaluates
/// when session value signals change (useful-yes, Pro retention yes) so the
/// card can appear right after the moment, and latches once shown so it
/// survives parent rebuilds until dismissed.
class ReferralInviteSection extends StatefulWidget {
  const ReferralInviteSection({
    super.key,
    required this.entryCount,
    required this.hasWeeklyReview,
    required this.hasConnectedProofCounter,
  });

  final int entryCount;
  final bool hasWeeklyReview;
  final bool hasConnectedProofCounter;

  @override
  State<ReferralInviteSection> createState() => _ReferralInviteSectionState();
}

class _ReferralInviteSectionState extends State<ReferralInviteSection> {
  bool _showing = false;
  String _source = '';

  @override
  void initState() {
    super.initState();
    ReferralInviteAfterValue.changes.addListener(_reevaluate);
  }

  @override
  void dispose() {
    ReferralInviteAfterValue.changes.removeListener(_reevaluate);
    super.dispose();
  }

  void _reevaluate() {
    if (!mounted || _showing) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_showing) {
      if (!ReferralInviteAfterValue.shouldShow(
        entryCount: widget.entryCount,
        hasWeeklyReview: widget.hasWeeklyReview,
        hasConnectedProofCounter: widget.hasConnectedProofCounter,
      )) {
        return const SizedBox.shrink();
      }
      _showing = true;
      ReferralInviteAfterValue.shownThisSession = true;
      _source =
          ReferralInviteAfterValue.sourceFor(
            entryCount: widget.entryCount,
            hasWeeklyReview: widget.hasWeeklyReview,
            hasConnectedProofCounter: widget.hasConnectedProofCounter,
          ) ??
          '';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ReferralInviteCard(
        source: _source,
        onDismissed: () => setState(() {
          ReferralInviteAfterValue.dismissedThisSession = true;
          _showing = false;
        }),
      ),
    );
  }
}

/// The invite card itself: calm copy, one copy-to-clipboard CTA, and a
/// clear "Not now". Nothing from the archive can appear here — the invite
/// text is a compile-time constant.
class ReferralInviteCard extends StatefulWidget {
  const ReferralInviteCard({
    super.key,
    required this.source,
    required this.onDismissed,
  });

  /// Stable id of the value moment that made the invite eligible.
  final String source;

  final VoidCallback onDismissed;

  @override
  State<ReferralInviteCard> createState() => _ReferralInviteCardState();
}

class _ReferralInviteCardState extends State<ReferralInviteCard> {
  bool _copied = false;

  Future<void> _copyInvite() async {
    // Copying an invite is itself a value signal the review prompt may
    // follow — stable ids only, never the invite text.
    ReviewPromptAfterValue.recordReferralInviteCopied();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.referralInviteCopied,
      source: widget.source,
      cardType: widget.source,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.referralInviteLinkCopied,
      source: ReferralInviteAfterValue.linkSource(widget.source),
      ref: ReferralInviteAfterValue.inviteRef,
    );
    // Source-specific invite copy plus the attribution link — both chosen
    // only by the stable source id; nothing dynamic can enter the clipboard.
    await Clipboard.setData(
      ClipboardData(
        text: ReferralInviteAfterValue.copiedInviteTextFor(widget.source),
      ),
    );
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.referralInviteSeen,
      source: widget.source,
      cardType: widget.source,
      oncePerSession: true,
    );
    // Proof moment: the source-specific earned-value line rendered above
    // the invite body. Stable ids only.
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.referralProofMomentSeen,
      source: widget.source,
      cardType: widget.source,
      oncePerSession: true,
    );

    return Container(
      key: const Key('referral_invite_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF2F7F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ReferralInviteAfterValue.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Proof line first — a fixed constant naming the kind of value
          // moment that earned this invite — then the unchanged body.
          Text(
            ReferralInviteAfterValue.proofLineFor(widget.source),
            key: const Key('referral_proof_moment_line'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ReferralInviteAfterValue.body,
            key: const Key('referral_invite_body'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_copied)
            Text(
              ReferralInviteAfterValue.copiedConfirmation,
              key: const Key('referral_invite_copied_line'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TextButton(
                    key: const Key('referral_invite_dismiss'),
                    onPressed: () {
                      ActivationFunnelAnalytics.track(
                        ActivationFunnelAnalytics.referralInviteDismissed,
                        source: widget.source,
                        cardType: widget.source,
                      );
                      widget.onDismissed();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    child: const Text(
                      ReferralInviteAfterValue.dismissLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: FilledButton(
                    key: const Key('referral_invite_cta'),
                    onPressed: _copyInvite,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    child: const Text(
                      ReferralInviteAfterValue.ctaLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
