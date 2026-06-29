import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_evidence_timeline_engine.dart';
import '../../features/early_archive/early_first_signal_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Sequential early evidence timeline — repeat, trigger, softening, helpful action.
class EarlyEvidenceTimelineCard extends StatelessWidget {
  const EarlyEvidenceTimelineCard({
    super.key,
    required this.timeline,
    this.compact = false,
    this.onRecordWhatHelped,
  });

  final EarlyEvidenceTimeline timeline;
  final bool compact;
  final VoidCallback? onRecordWhatHelped;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context)
        .copyWith(fontSize: compact ? 17 : null);
    final subtitleStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
      fontSize: compact ? 13 : null,
    );
    final itemTitleStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: compact ? 14 : null,
    );
    final itemBodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
      fontSize: compact ? 13 : null,
    );

    return Container(
      key: Key('early_evidence_timeline_card_${compact ? 'compact' : 'full'}'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            timeline.title,
            key: const Key('early_evidence_timeline_title'),
            style: titleStyle,
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              timeline.subtitle,
              key: const Key('early_evidence_timeline_subtitle'),
              style: subtitleStyle,
            ),
          ],
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          for (var i = 0; i < timeline.items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      key: Key('early_evidence_timeline_dot_${timeline.items[i].kind.name}'),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < timeline.items.length - 1)
                      Container(
                        width: 2,
                        height: compact ? 28 : 36,
                        color: AppColors.accentPrimary.withValues(alpha: 0.25),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < timeline.items.length - 1
                          ? (compact ? AppSpacing.sm : AppSpacing.md)
                          : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeline.items[i].title,
                          key: Key(
                            'early_evidence_timeline_item_title_${timeline.items[i].kind.name}',
                          ),
                          style: itemTitleStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeline.items[i].body,
                          key: Key(
                            'early_evidence_timeline_item_body_${timeline.items[i].kind.name}',
                          ),
                          style: itemBodyStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (onRecordWhatHelped != null &&
              timeline.showsSofterReturn &&
              !timeline.showsHelpfulAction) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('early_evidence_timeline_record_what_helped_cta'),
              onPressed: onRecordWhatHelped,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
              ),
              child: Text(EarlyFirstSignalCopy.recordWhatHelpedCta),
            ),
          ],
        ],
      ),
    );
  }
}
