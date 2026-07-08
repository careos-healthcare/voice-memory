import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_invite/beta_invite_analytics.dart';
import '../../features/beta_invite/beta_invite_model.dart';
import '../../features/share/archive_share_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Beta-only invite loop card — generic clipboard copy, no private evidence.
class BetaInviteCard extends StatefulWidget {
  const BetaInviteCard({
    super.key,
    required this.result,
    required this.onDismiss,
    this.compact = false,
  });

  const BetaInviteCard.test({
    super.key,
    required this.result,
    this.onDismiss,
    this.compact = false,
  });

  final BetaInviteLoopResult result;
  final VoidCallback? onDismiss;
  final bool compact;

  @override
  State<BetaInviteCard> createState() => _BetaInviteCardState();
}

class _BetaInviteCardState extends State<BetaInviteCard> {
  var _trackedSeen = false;

  String get _triggerValue =>
      widget.result.trigger?.analyticsValue ?? 'none';

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    BetaInviteAnalytics.seen(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      trigger: _triggerValue,
    );
  }

  Future<void> _handleCopyInvite() async {
    BetaInviteAnalytics.copied(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      trigger: _triggerValue,
    );
    await ArchiveShareActions.copyShareText(
      context,
      text: widget.result.inviteText,
      showConfirmation: true,
    );
  }

  void _handleDismiss() {
    BetaInviteAnalytics.dismissed(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      trigger: _triggerValue,
    );
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('beta_invite_card_hidden'));
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('beta_invite_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('beta_invite_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('beta_invite_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('beta_invite_dismiss'),
                  onPressed: widget.onDismiss == null ? null : _handleDismiss,
                  child: Text(widget.result.secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('beta_invite_copy'),
                  onPressed: _handleCopyInvite,
                  child: Text(widget.result.cta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
