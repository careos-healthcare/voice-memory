import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/archive_clean/archive_clean_section_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// One organized entry structure for the Patterns archive — day, week, pattern,
/// search, and older moments without a wall of duplicate cards.
class ArchiveCleanViewCard extends StatefulWidget {
  const ArchiveCleanViewCard({
    required this.sections, required this.onSectionTap, super.key,
  });

  final List<ArchiveCleanSection> sections;
  final void Function(ArchiveCleanSection section) onSectionTap;

  static const Color warmSurface = Color(0xFFFFFBF5);
  static const Color warmBorder = AppColors.warmBorder;

  @override
  State<ArchiveCleanViewCard> createState() => _ArchiveCleanViewCardState();
}

class _ArchiveCleanViewCardState extends State<ArchiveCleanViewCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveCleanViewShown();
  }

  void _tap(ArchiveCleanSection section) {
    ActivationTracker.trackArchiveCleanSectionTapped();
    widget.onSectionTap(section);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ArchiveCleanViewCard.warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArchiveCleanViewCard.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your archive',
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Find moments by day, week, or pattern.',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < widget.sections.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _sectionRow(widget.sections[i]),
          ],
        ],
      ),
    );
  }

  Widget _sectionRow(ArchiveCleanSection section) {
    return InkWell(
      onTap: () => _tap(section),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.title,
                          style: VoiceMemoryTypography.cardTitleStyle()
                              .copyWith(fontSize: 15),
                        ),
                      ),
                      if (section.count != null)
                        Text(
                          '${section.count}',
                          style: VoiceMemoryTypography.metadataStyle(
                            color: AppColors.textSecondary,
                          ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.subtitle,
                    style: VoiceMemoryTypography.metadataStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => _tap(section),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(section.primaryCtaLabel),
            ),
          ],
        ),
      ),
    );
  }
}