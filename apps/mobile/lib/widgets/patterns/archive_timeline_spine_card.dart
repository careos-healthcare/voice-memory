import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_analytics.dart';
import 'package:archiveme_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Unified archive timeline spine — one section, no Pro CTA.
class ArchiveTimelineSpineCard extends StatefulWidget {
  const ArchiveTimelineSpineCard({
    required this.result, required this.source, super.key,
  });

  const ArchiveTimelineSpineCard.test({
    required this.result, required this.source, super.key,
  });

  final ArchiveTimelineSpineResult result;
  final String source;

  @override
  State<ArchiveTimelineSpineCard> createState() =>
      _ArchiveTimelineSpineCardState();
}

class _ArchiveTimelineSpineCardState extends State<ArchiveTimelineSpineCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ArchiveTimelineSpineAnalytics.seen(
      source: widget.source,
      result: widget.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final rowLabelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('archive_timeline_spine_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('archive_timeline_spine_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.subtitle,
            key: const Key('archive_timeline_spine_subtitle'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.explanation,
            key: const Key('archive_timeline_spine_explanation'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final row in widget.result.rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        row.label,
                        key: Key('archive_timeline_spine_row_${row.id.name}'),
                        style: rowLabelStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.detail,
                        key: Key(
                          'archive_timeline_spine_row_detail_${row.id.name}',
                        ),
                        style: bodyStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            widget.result.currentWeightLabel,
            key: Key(
              'archive_timeline_spine_weight_${widget.result.currentWeight.name}',
            ),
            style: rowLabelStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.footer,
            key: const Key('archive_timeline_spine_footer'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.differentiationLine,
            key: const Key('archive_timeline_spine_differentiation'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.proBridgeCopy,
            key: const Key('archive_timeline_spine_pro_bridge_copy'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}