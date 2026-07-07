import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/open_capture/open_capture_analytics.dart';
import '../../features/open_capture/open_capture_copy.dart';
import '../../features/open_capture/open_capture_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact open-capture chips — prompt context only, stays on Record.
class OpenCapturePromptChips extends StatefulWidget {
  const OpenCapturePromptChips({
    super.key,
    required this.source,
    required this.entryCount,
    required this.onChipTap,
    this.usePromptPrefill = true,
  });

  const OpenCapturePromptChips.test({
    super.key,
    required this.source,
    required this.entryCount,
    required this.onChipTap,
    this.usePromptPrefill = true,
  });

  final String source;
  final int entryCount;
  final ValueChanged<OpenCaptureChip> onChipTap;
  final bool usePromptPrefill;

  @override
  State<OpenCapturePromptChips> createState() => _OpenCapturePromptChipsState();
}

class _OpenCapturePromptChipsState extends State<OpenCapturePromptChips> {
  var _trackedSeen = false;
  OpenCaptureChipType? _selectedChipType;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    OpenCaptureAnalytics.seen(
      source: widget.source,
      entryCount: widget.entryCount,
    );
  }

  void _handleChipTap(OpenCaptureChip chip) {
    OpenCaptureAnalytics.chipTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      chipType: chip.type,
    );
    setState(() => _selectedChipType = chip.type);
    widget.onChipTap(chip);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return Column(
      key: const Key('open_capture_prompt_chips'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          OpenCaptureCopy.header,
          key: const Key('open_capture_header'),
          style: labelStyle,
        ),
        const SizedBox(height: 4),
        Text(
          OpenCaptureCopy.subline,
          key: const Key('open_capture_subline'),
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final chip in OpenCaptureChip.all)
              FilterChip(
                key: Key('open_capture_chip_${chip.type.name}'),
                label: Text(chip.label),
                selected: _selectedChipType == chip.type,
                onSelected: (_) => _handleChipTap(chip),
                showCheckmark: false,
              ),
          ],
        ),
        if (_selectedChipType != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.usePromptPrefill
                ? OpenCaptureCopy.chipSelectedCopy
                : OpenCaptureCopy.fallbackHelper,
            key: const Key('open_capture_chip_selected_copy'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          if (widget.usePromptPrefill) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              OpenCaptureCopy.differentiation,
              key: const Key('open_capture_differentiation'),
              style: bodyStyle,
            ),
          ],
        ],
      ],
    );
  }
}
