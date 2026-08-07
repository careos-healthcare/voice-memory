import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_boundary_response_copy.dart';
import '../features/capacity_loop/capacity_boundary_response_models.dart';
import '../features/capacity_loop/capacity_boundary_response_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact Archive Home card for capacity boundary response — templates only.
class CapacityBoundaryResponseCard extends StatelessWidget {
  const CapacityBoundaryResponseCard({
    super.key,
    required this.result,
    this.onPrimaryAction,
    this.sampleMode = false,
  });

  const CapacityBoundaryResponseCard.test({
    super.key,
    required this.result,
    this.onPrimaryAction,
    this.sampleMode = false,
  });

  final CapacityBoundaryResponseResult result;
  final VoidCallback? onPrimaryAction;
  final bool sampleMode;

  @override
  Widget build(BuildContext context) {
    if (sampleMode ||
        ScreenshotMode.enabled ||
        !result.hasFeature ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(
        key: Key('capacity_boundary_response_card_hidden'),
      );
    }

    return Container(
      key: const Key('capacity_boundary_response_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CapacityBoundaryResponseCopy.cardEyebrow,
            key: const Key('capacity_boundary_response_card_eyebrow'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.title,
            key: const Key('capacity_boundary_response_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.cardSummary,
            key: const Key('capacity_boundary_response_card_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('capacity_boundary_response_card_primary_button'),
            onPressed:
                onPrimaryAction ?? () => context.push(result.primaryRoute),
            child: Text(result.primaryCtaLabel),
          ),
        ],
      ),
    );
  }
}

/// Reusable picker for weekly review and full screen — fixed templates only.
class CapacityBoundaryResponsePicker extends StatefulWidget {
  const CapacityBoundaryResponsePicker({
    super.key,
    required this.result,
    this.compact = false,
    this.onSelectionChanged,
  });

  final CapacityBoundaryResponseResult result;
  final bool compact;
  final VoidCallback? onSelectionChanged;

  @override
  State<CapacityBoundaryResponsePicker> createState() =>
      _CapacityBoundaryResponsePickerState();
}

class _CapacityBoundaryResponsePickerState
    extends State<CapacityBoundaryResponsePicker> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.result.selectedResponseId.isNotEmpty
        ? widget.result.selectedResponseId
        : null;
  }

  Future<void> _saveSelection(String responseId) async {
    await CapacityBoundaryResponseStore.instance().saveSelection(responseId);
    if (!mounted) return;
    setState(() => _selectedId = responseId);
    widget.onSelectionChanged?.call();
  }

  Future<void> _copySelected() async {
    final text = CapacityBoundaryResponseCopy.textForId(_selectedId);
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    await CapacityBoundaryResponseStore.instance().recordCopied();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Response copied')));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.hasFeature) {
      return const SizedBox.shrink(
        key: Key('capacity_boundary_response_picker_hidden'),
      );
    }

    return Column(
      key: const Key('capacity_boundary_response_picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            widget.result.title,
            key: const Key('capacity_boundary_response_picker_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.subtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ] else ...[
          Text(
            CapacityBoundaryResponseCopy.weeklyReviewSectionTitle,
            key: const Key('capacity_boundary_response_picker_section_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ...widget.result.templates.map(
          (template) => RadioListTile<String>(
            key: Key('capacity_boundary_response_option_${template.id}'),
            value: template.id,
            groupValue: _selectedId,
            onChanged: (value) {
              if (value == null) return;
              unawaited(_saveSelection(value));
            },
            title: Text(
              template.text,
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
            contentPadding: EdgeInsets.zero,
            dense: widget.compact,
          ),
        ),
        if (_selectedId != null) ...[
          if (widget.result.recommendedResponseNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.recommendedResponseNote,
              key: const Key('capacity_boundary_response_recommendation_note'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('capacity_boundary_response_copy_button'),
            onPressed: _copySelected,
            child: const Text(CapacityBoundaryResponseCopy.copyResponseCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('capacity_boundary_response_use_next_time_button'),
            onPressed: _copySelected,
            child: Text(widget.result.secondaryCtaLabel),
          ),
        ],
      ],
    );
  }
}
