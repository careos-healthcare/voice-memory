import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/tomorrow_return/compelling_check_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Shows a sharpened tomorrow check with optional tone chooser.
class CompellingCheckPreview extends StatefulWidget {
  const CompellingCheckPreview({
    super.key,
    required this.check,
    this.options,
    this.selectedSharpnessLabel,
    this.onSharpnessSelected,
    this.compact = false,
    this.trackShown = true,
  });

  final CompellingCheckQuestion check;
  final Map<String, CompellingCheckQuestion>? options;
  final String? selectedSharpnessLabel;
  final ValueChanged<CompellingCheckQuestion>? onSharpnessSelected;
  final bool compact;
  final bool trackShown;

  @override
  State<CompellingCheckPreview> createState() => _CompellingCheckPreviewState();
}

class _CompellingCheckPreviewState extends State<CompellingCheckPreview> {
  static const Color _warmBorder = Color(0xFFF5E6D3);
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackShown();
  }

  @override
  void didUpdateWidget(covariant CompellingCheckPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.check.question != widget.check.question) {
      _tracked = false;
      _trackShown();
    }
  }

  void _trackShown() {
    if (!widget.trackShown || _tracked) return;
    _tracked = true;
    ActivationTracker.trackCompellingCheckShown();
  }

  void _onSelect(String label, CompellingCheckQuestion option) {
    ActivationTracker.trackCompellingCheckSelected();
    if (label == CompellingCheckSharpness.mostSpecific) {
      ActivationTracker.trackCompellingCheckMostSpecificSelected();
    }
    widget.onSharpnessSelected?.call(option);
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.check;
    final options = widget.options;
    final selected = widget.selectedSharpnessLabel ?? check.sharpnessLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (options != null && options.length > 1) ...[
          Text(
            ConsumerUiCopy.chooseTomorrowQuestionLabel,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in CompellingCheckSharpness.all)
                if (options.containsKey(label))
                  ChoiceChip(
                    label: Text(label),
                    selected: label == selected,
                    showCheckmark: false,
                    onSelected: widget.onSharpnessSelected == null
                        ? null
                        : (_) => _onSelect(label, options[label]!),
                    backgroundColor: Colors.white,
                    selectedColor:
                        AppColors.accentPrimary.withValues(alpha: 0.15),
                    side: BorderSide(
                      color: label == selected
                          ? AppColors.accentPrimary
                          : _warmBorder,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          check.sharpnessLabel,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.accentPrimary,
          ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          check.question,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(
            fontSize: widget.compact ? 14 : 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        if (!widget.compact) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            check.whyThisCheck,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _warmBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ConsumerUiCopy.resultNextCheckExampleLabel,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  check.exampleAnswer,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
