import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/return_after_proof_lift_v2/return_after_proof_lift_v2_analytics.dart';
import '../../features/return_after_proof_lift_v2/return_after_proof_lift_v2_copy.dart';
import '../../features/return_after_proof_lift_v2/return_after_proof_lift_v2_model.dart';
import '../../features/return_after_proof_lift_v2/return_after_proof_lift_v2_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class ReturnAfterProofLiftV2Card extends StatefulWidget {
  const ReturnAfterProofLiftV2Card({
    super.key,
    required this.result,
    required this.onPrimaryCta,
    required this.onPromptSelected,
  });

  const ReturnAfterProofLiftV2Card.test({
    super.key,
    required this.result,
    required this.onPrimaryCta,
    required this.onPromptSelected,
  });

  final ReturnAfterProofLiftV2Result result;
  final VoidCallback onPrimaryCta;
  final ValueChanged<String> onPromptSelected;

  @override
  State<ReturnAfterProofLiftV2Card> createState() =>
      _ReturnAfterProofLiftV2CardState();
}

class _ReturnAfterProofLiftV2CardState
    extends State<ReturnAfterProofLiftV2Card> {
  var _trackedSeen = false;
  var _dismissedToday = false;
  var _watchExpanded = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _dismissedToday) return;
    _trackedSeen = true;
    ReturnAfterProofLiftV2Analytics.seen(result: widget.result);
  }

  Future<void> _handleDismiss() async {
    ReturnAfterProofLiftV2Analytics.dismissed(result: widget.result);
    await ReturnAfterProofLiftV2Store.dismissForDay();
    if (!mounted) return;
    setState(() => _dismissedToday = true);
  }

  void _handlePrimary() {
    ReturnAfterProofLiftV2Analytics.ctaTapped(
      result: widget.result,
      actionType: ReturnAfterProofLiftV2ActionType.saveNextReturn,
    );
    widget.onPromptSelected(widget.result.promptLine);
    widget.onPrimaryCta();
  }

  void _handleSecondary() {
    ReturnAfterProofLiftV2Analytics.ctaTapped(
      result: widget.result,
      actionType: ReturnAfterProofLiftV2ActionType.expandWatch,
    );
    setState(() => _watchExpanded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('return_after_proof_lift_v2_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('return_after_proof_lift_v2_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('return_after_proof_lift_v2_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('return_after_proof_lift_v2_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (_watchExpanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.watchLine,
              key: const Key('return_after_proof_lift_v2_watch_line'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('return_after_proof_lift_v2_primary_cta'),
            onPressed: _handlePrimary,
            child: Text(widget.result.primaryCta),
          ),
          TextButton(
            key: const Key('return_after_proof_lift_v2_secondary_cta'),
            onPressed: _handleSecondary,
            child: Text(widget.result.secondaryCta),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('return_after_proof_lift_v2_dismiss'),
              onPressed: () => unawaited(_handleDismiss()),
              child: Text(ReturnAfterProofLiftV2Copy.dismissCta),
            ),
          ),
        ],
      ),
    );
  }
}
