import 'package:flutter/material.dart';

import '../../billing/pro_value_preview_model.dart';
import '../../features/activation/activation_tracker.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Shows what Pro unlocks before the user reaches the paywall.
class ProValuePreviewCard extends StatefulWidget {
  const ProValuePreviewCard({
    super.key,
    required this.preview,
    required this.onUnlock,
    this.onDismiss,
    this.showActions = true,
    this.trackShown = true,
  });

  final ProValuePreview preview;
  final VoidCallback onUnlock;
  final VoidCallback? onDismiss;
  final bool showActions;
  final bool trackShown;

  @override
  State<ProValuePreviewCard> createState() => _ProValuePreviewCardState();
}

class _ProValuePreviewCardState extends State<ProValuePreviewCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackShown();
  }

  @override
  void didUpdateWidget(covariant ProValuePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview.type != widget.preview.type) {
      _tracked = false;
      _trackShown();
    }
  }

  void _trackShown() {
    if (!widget.trackShown || _tracked) return;
    _tracked = true;
    ActivationTracker.trackProValuePreviewShown(widget.preview.typeId);
  }

  void _onUnlock() {
    ActivationTracker.trackProValuePreviewUnlockTapped();
    widget.onUnlock();
  }

  void _onDismiss() {
    ActivationTracker.trackProValuePreviewDismissed();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            preview.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final bullet in preview.previewBullets) ...[
            _bulletRow(bullet),
            const SizedBox(height: 6),
          ],
          if (widget.showActions) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _onUnlock,
                child: Text(preview.ctaLabel),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _onDismiss,
                child: const Text(ConsumerUiCopy.paywallSecondaryCta),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bulletRow(String label) {
    return Row(
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
            label,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.35),
          ),
        ),
      ],
    );
  }
}
