import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pro_understanding_lift/pro_understanding_lift_analytics.dart';
import 'package:archiveme_mobile/features/pro_understanding_lift/pro_understanding_lift_model.dart';
import 'package:archiveme_mobile/features/pro_understanding_lift/pro_understanding_lift_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class ProUnderstandingLiftCard extends StatefulWidget {
  const ProUnderstandingLiftCard({
    required this.result, required this.onSeePro, super.key,
    this.compact = false,
  });

  const ProUnderstandingLiftCard.test({
    required this.result, required this.onSeePro, super.key,
    this.compact = false,
  });

  final ProUnderstandingLiftResult result;
  final VoidCallback onSeePro;
  final bool compact;

  @override
  State<ProUnderstandingLiftCard> createState() =>
      _ProUnderstandingLiftCardState();
}

class _ProUnderstandingLiftCardState extends State<ProUnderstandingLiftCard> {
  var _trackedSeen = false;
  var _dismissedToday = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _dismissedToday) return;
    _trackedSeen = true;
    ProUnderstandingLiftAnalytics.seen(result: widget.result);
  }

  Future<void> _handleDismiss() async {
    ProUnderstandingLiftAnalytics.dismissed(result: widget.result);
    await ProUnderstandingLiftStore.dismissForDay();
    if (!mounted) return;
    setState(() => _dismissedToday = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('pro_understanding_lift_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('pro_understanding_lift_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pro_understanding_lift_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('pro_understanding_lift_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          for (final bullet in widget.result.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: bodyStyle.copyWith(color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      key: Key('pro_understanding_lift_bullet_$bullet'),
                      style: bodyStyle.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            widget.result.supportLine,
            key: const Key('pro_understanding_lift_support_line'),
            style: bodyStyle,
          ),
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          FilledButton(
            key: const Key('pro_understanding_lift_primary_cta'),
            onPressed: () {
              ProUnderstandingLiftAnalytics.ctaTapped(result: widget.result);
              widget.onSeePro();
            },
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('pro_understanding_lift_secondary_cta'),
            onPressed: () => unawaited(_handleDismiss()),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}