import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_activation_path/beta_activation_path_analytics.dart';
import '../../features/beta_activation_path/beta_activation_path_model.dart';
import '../../features/beta_activation_path/beta_activation_path_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Beta-only activation path card — generic copy, no fake entries.
class BetaActivationPathCard extends StatefulWidget {
  const BetaActivationPathCard({
    super.key,
    required this.result,
    required this.onPrimaryCta,
    this.compact = false,
    this.showDiagnosis = false,
  });

  const BetaActivationPathCard.test({
    super.key,
    required this.result,
    this.onPrimaryCta,
    this.compact = false,
    this.showDiagnosis = false,
  });

  final BetaActivationPathResult result;
  final VoidCallback? onPrimaryCta;
  final bool compact;
  final bool showDiagnosis;

  @override
  State<BetaActivationPathCard> createState() => _BetaActivationPathCardState();
}

class _BetaActivationPathCardState extends State<BetaActivationPathCard> {
  var _trackedSeen = false;
  var _dismissedToday = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    BetaActivationPathAnalytics.seen(result: widget.result);
  }

  void _handlePrimaryCta() {
    BetaActivationPathAnalytics.ctaTapped(
      result: widget.result,
      actionType: widget.result.primaryActionType,
    );
    widget.onPrimaryCta?.call();
  }

  Future<void> _handleSecondaryCta() async {
    BetaActivationPathAnalytics.ctaTapped(
      result: widget.result,
      actionType: widget.result.secondaryActionType,
    );
    BetaActivationPathAnalytics.dismissed(result: widget.result);
    await BetaActivationPathStore.dismissForDay();
    if (!mounted) return;
    setState(() => _dismissedToday = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('beta_activation_path_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('beta_activation_path_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showDiagnosis) ...[
            Text(
              widget.result.diagnosis,
              key: const Key('beta_activation_path_diagnosis'),
              style: ArchiveMobileTypography.caption(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            widget.result.title,
            key: const Key('beta_activation_path_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('beta_activation_path_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton(
              key: const Key('beta_activation_path_primary_cta'),
              onPressed: widget.onPrimaryCta == null ? null : _handlePrimaryCta,
              child: Text(widget.result.primaryCta),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('beta_activation_path_secondary_cta'),
            onPressed: () => unawaited(_handleSecondaryCta()),
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}
