import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/archive_memory/memory_quality_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Compact chip showing how clear a pattern memory is.
class MemoryQualityChip extends StatefulWidget {
  const MemoryQualityChip({super.key, required this.quality, this.onTap});

  final MemoryQuality quality;
  final VoidCallback? onTap;

  @override
  State<MemoryQualityChip> createState() => _MemoryQualityChipState();
}

class _MemoryQualityChipState extends State<MemoryQualityChip> {
  bool _expanded = false;

  static const Color _warmBorder = AppColors.warmBorder;

  @override
  void initState() {
    super.initState();
    if (widget.quality.shouldShow) {
      ActivationTracker.trackMemoryQualityShown(widget.quality.level);
    }
  }

  void _handleTap() {
    if (!widget.quality.shouldShow) return;
    ActivationTracker.trackMemoryQualityTapped(widget.quality.level);
    widget.onTap?.call();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.quality.shouldShow) return const SizedBox.shrink();

    final quality = widget.quality;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _warmBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    quality.label,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            quality.helperText,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, height: 1.4),
          ),
        ],
      ],
    );
  }
}
