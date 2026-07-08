import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pro_visibility_lift/pro_visibility_lift_analytics.dart';
import '../../features/pro_visibility_lift/pro_visibility_lift_model.dart';
import '../../features/pro_visibility_lift/pro_visibility_lift_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class ProVisibilityLiftCard extends StatefulWidget {
  const ProVisibilityLiftCard({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  const ProVisibilityLiftCard.test({
    super.key,
    required this.result,
    required this.onSeePro,
    this.compact = false,
  });

  final ProVisibilityLiftResult result;
  final VoidCallback onSeePro;
  final bool compact;

  @override
  State<ProVisibilityLiftCard> createState() => _ProVisibilityLiftCardState();
}

class _ProVisibilityLiftCardState extends State<ProVisibilityLiftCard> {
  var _trackedSeen = false;
  var _dismissedToday = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _dismissedToday) return;
    _trackedSeen = true;
    ProVisibilityLiftAnalytics.seen(result: widget.result);
  }

  Future<void> _handleDismiss() async {
    ProVisibilityLiftAnalytics.dismissed(result: widget.result);
    await ProVisibilityLiftStore.dismissForDay();
    if (!mounted) return;
    setState(() => _dismissedToday = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday || !widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('pro_visibility_lift_card_hidden'));
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('pro_visibility_lift_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pro_visibility_lift_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('pro_visibility_lift_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          FilledButton(
            key: const Key('pro_visibility_lift_primary_cta'),
            onPressed: () {
              ProVisibilityLiftAnalytics.ctaTapped(result: widget.result);
              widget.onSeePro();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('pro_visibility_lift_secondary_cta'),
            onPressed: () => unawaited(_handleDismiss()),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}
