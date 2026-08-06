import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/capture_context_tags.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Optional post-save context tag picker — one tag, always skippable.
class CaptureContextTagCard extends StatefulWidget {
  const CaptureContextTagCard({
    super.key,
    required this.onSaveTag,
    required this.onSkip,
  });

  final ValueChanged<String> onSaveTag;
  final VoidCallback onSkip;

  @override
  State<CaptureContextTagCard> createState() => _CaptureContextTagCardState();
}

class _CaptureContextTagCardState extends State<CaptureContextTagCard> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('capture_context_tag_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            VisibleArchiveProofCopy.captureContextTagTitle,
            key: const Key('capture_context_tag_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            VisibleArchiveProofCopy.captureContextTagHelper,
            key: const Key('capture_context_tag_helper'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final tag in CaptureContextTags.all)
                ChoiceChip(
                  key: Key('capture_context_tag_${tag.id}'),
                  label: Text(tag.label),
                  selected: _selectedId == tag.id,
                  onSelected: (selected) =>
                      setState(() => _selectedId = selected ? tag.id : null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                key: const Key('capture_context_tag_skip'),
                onPressed: widget.onSkip,
                child: Text(VisibleArchiveProofCopy.captureContextTagSkip),
              ),
              FilledButton(
                key: const Key('capture_context_tag_save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                onPressed: _selectedId == null
                    ? null
                    : () => widget.onSaveTag(_selectedId!),
                child: Text(VisibleArchiveProofCopy.captureContextTagSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
