import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/archive_change_timeline_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../proof/proof_surface_why_appeared_disclosure.dart';
import '../../features/archive_proof/proof_surface_why_appeared_copy.dart';

/// Vertical evidence trail tying archive proof moments together over time.
class ArchiveChangeTimelineCard extends StatelessWidget {
  const ArchiveChangeTimelineCard({
    super.key,
    required this.timeline,
    required this.entryCount,
  });

  final ArchiveChangeTimeline timeline;
  final int entryCount;

  static Future<void> showSheet(
    BuildContext context, {
    required ArchiveChangeTimeline timeline,
    required int entryCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          child: ArchiveChangeTimelineCard(
            timeline: timeline,
            entryCount: entryCount,
          ),
        ),
      ),
    );
  }

  static const Color _railColor = Color(0xFFCBD5E0);

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
      fontSize: 13,
    );
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.3,
    );
    final chipStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    return Container(
      key: const Key('archive_change_timeline_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF7FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            timeline.title,
            key: const Key('archive_change_timeline_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timeline.subtitle,
            key: const Key('archive_change_timeline_subtitle'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Column(
            key: const Key('archive_change_timeline_chain'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < timeline.items.length; i++)
                _TimelineRow(
                  item: timeline.items[i],
                  isLast: i == timeline.items.length - 1,
                  labelStyle: labelStyle,
                  bodyStyle: bodyStyle,
                  chipStyle: chipStyle,
                ),
            ],
          ),
          ProofSurfaceWhyAppearedDisclosure(
            body: ProofSurfaceWhyAppearedCopy.evidenceTimeline,
            surfaceKey: 'archive_change_timeline',
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.isLast,
    required this.labelStyle,
    required this.bodyStyle,
    required this.chipStyle,
  });

  final ArchiveChangeTimelineItem item;
  final bool isLast;
  final TextStyle labelStyle;
  final TextStyle bodyStyle;
  final TextStyle chipStyle;

  @override
  Widget build(BuildContext context) {
    const dotSize = 8.0;
    const railWidth = 2.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  key: Key('archive_change_timeline_dot_${item.kind.name}'),
                  width: dotSize,
                  height: dotSize,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: ArchiveChangeTimelineCard._railColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ArchiveChangeTimelineCard._railColor
                          .withValues(alpha: 0.35),
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: railWidth,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: ArchiveChangeTimelineCard._railColor
                          .withValues(alpha: 0.22),
                    ),
                  )
                else
                  const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    key: Key('archive_change_timeline_label_${item.kind.name}'),
                    style: labelStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    key: Key('archive_change_timeline_body_${item.kind.name}'),
                    style: bodyStyle,
                  ),
                  if (item.hasPhrase) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${item.phrase!}"',
                      key: Key(
                        'archive_change_timeline_phrase_${item.kind.name}',
                      ),
                      style: chipStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
