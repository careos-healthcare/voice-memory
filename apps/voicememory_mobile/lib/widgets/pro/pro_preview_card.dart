import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pro_preview/pro_preview_analytics.dart';
import '../../features/pro_preview/pro_preview_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Concrete Pro preview before paywall — generic rows only.
class ProPreviewCard extends StatefulWidget {
  const ProPreviewCard({
    super.key,
    required this.result,
    required this.onSeePro,
    required this.onDismiss,
    this.compact = false,
  });

  const ProPreviewCard.test({
    super.key,
    required this.result,
    this.onSeePro,
    this.onDismiss,
    this.compact = false,
  });

  final ProPreviewResult result;
  final VoidCallback? onSeePro;
  final VoidCallback? onDismiss;
  final bool compact;

  @override
  State<ProPreviewCard> createState() => _ProPreviewCardState();
}

class _ProPreviewCardState extends State<ProPreviewCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    ProPreviewAnalytics.seen(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      hasTimelineProof: widget.result.hasTimelineProof,
      hasFirstProof: widget.result.hasFirstProof,
    );
  }

  void _handleSeePro() {
    ProPreviewAnalytics.ctaTapped(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      hasTimelineProof: widget.result.hasTimelineProof,
      hasFirstProof: widget.result.hasFirstProof,
    );
    widget.onSeePro?.call();
  }

  void _handleDismiss() {
    ProPreviewAnalytics.dismissed(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      hasTimelineProof: widget.result.hasTimelineProof,
      hasFirstProof: widget.result.hasFirstProof,
    );
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('pro_preview_card_hidden'));
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final rowStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(height: 1.35);

    return Container(
      key: const Key('pro_preview_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pro_preview_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('pro_preview_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in widget.result.previewRows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    row.label,
                    key: Key('pro_preview_row_${row.id.name}'),
                    style: rowStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pro_preview_dismiss'),
                  onPressed: widget.onDismiss == null ? null : _handleDismiss,
                  child: Text(widget.result.secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('pro_preview_cta'),
                  onPressed: widget.onSeePro == null ? null : _handleSeePro,
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
