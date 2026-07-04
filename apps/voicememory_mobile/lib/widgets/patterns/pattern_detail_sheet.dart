import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta_activation/beta_activation_summary_tracker.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pattern_detail/pattern_detail_copy.dart';
import '../../features/pattern_detail/pattern_detail_model.dart';
import '../../features/pro_memory/pro_memory_boundary_copy.dart';
import '../../features/pro_memory/pro_memory_boundary_engine.dart';
import '../../features/share_card/share_card_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../archive_paywall/pro_memory_upgrade_bridge.dart';
import '../record/entry_importance_button.dart';
import '../share_card/share_card_action_card.dart';

/// Bottom sheet explaining one confirmed pattern and its evidence.
class PatternDetailSheet extends StatelessWidget {
  const PatternDetailSheet({
    super.key,
    required this.detail,
    this.entryCount = 0,
    this.isPro = true,
    this.onSeePro,
    this.shareCard,
  });

  final PatternDetailResult detail;
  final int entryCount;
  final bool isPro;
  final VoidCallback? onSeePro;
  final ShareCardModel? shareCard;

  static Future<void> show(
    BuildContext context, {
    required PatternDetailResult detail,
    int entryCount = 0,
    bool isPro = true,
    VoidCallback? onSeePro,
    ShareCardModel? shareCard,
  }) {
    unawaited(BetaActivationSummaryTracker.trackPatternDetailsOpened());
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PatternDetailSheet(
          detail: detail,
          entryCount: entryCount,
          isPro: isPro,
          onSeePro: onSeePro,
          shareCard: shareCard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);
    final fallbackStyle = secondaryStyle.copyWith(fontStyle: FontStyle.italic);
    final visibleMoments = ProMemoryBoundaryEngine.visibleRecentMoments(
      moments: detail.savedMoments,
      isPro: isPro,
    );
    final gatedOlderCount = ProMemoryBoundaryEngine.gatedOlderMomentCount(
      totalMomentCount: detail.savedMoments.length,
      isPro: isPro,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('pattern_detail_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PatternDetailCopy.sheetTitle,
                key: const Key('pattern_detail_sheet_title'),
                style: titleStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.patternLabelHeading,
                key: const Key('pattern_detail_pattern_label_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.patternLabel,
                key: const Key('pattern_detail_pattern_label'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.evidenceHeading,
                key: const Key('pattern_detail_evidence_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                PatternDetailCopy.evidenceIntro,
                key: const Key('pattern_detail_evidence_intro'),
                style: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final phrase in detail.evidencePhrases) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: bodyStyle),
                    Expanded(
                      child: Text(
                        '"$phrase"',
                        key: Key('pattern_detail_evidence_phrase_$phrase'),
                        style: bodyStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatChangedHeading,
                key: const Key('pattern_detail_what_changed_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatChangedBody,
                key: const Key('pattern_detail_what_changed_body'),
                style: detail.whatChangedSupported ? bodyStyle : fallbackStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatHelpedHeading,
                key: const Key('pattern_detail_what_helped_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatHelpedBody,
                key: const Key('pattern_detail_what_helped_body'),
                style: detail.whatHelpedSupported ? bodyStyle : fallbackStyle,
              ),
              if (detail.hasSavedMoments) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  PatternDetailCopy.savedMomentsHeading,
                  key: const Key('pattern_detail_saved_moments_heading'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < visibleMoments.length; i++)
                  _MomentRow(
                    moment: visibleMoments[i],
                    index: i,
                    entryCount: entryCount,
                  ),
                if (gatedOlderCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    ProMemoryBoundaryCopy.olderEvidenceTitle,
                    key: const Key('pattern_detail_older_evidence_title'),
                    style: labelStyle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ProMemoryBoundaryCopy.olderEvidenceBody,
                    key: const Key('pattern_detail_older_evidence_body'),
                    style: secondaryStyle,
                  ),
                  if (onSeePro != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ProMemoryUpgradeBridge(
                      compact: true,
                      showNotNow: false,
                      onSeePro: onSeePro!,
                    ),
                  ],
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                PatternDetailCopy.whatToWatchHeading,
                key: const Key('pattern_detail_what_to_watch_heading'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.whatToWatchNextBody,
                key: const Key('pattern_detail_what_to_watch_body'),
                style: bodyStyle,
              ),
              if (shareCard != null) ...[
                const SizedBox(height: AppSpacing.md),
                ShareCardActionCard(
                  model: shareCard!,
                  source: 'pattern_detail',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentRow extends StatefulWidget {
  const _MomentRow({
    required this.moment,
    required this.index,
    required this.entryCount,
  });

  final PatternDetailMoment moment;
  final int index;
  final int entryCount;

  @override
  State<_MomentRow> createState() => _MomentRowState();
}

class _MomentRowState extends State<_MomentRow> {
  PatternDetailMoment get moment => widget.moment;
  int get index => widget.index;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textPrimary,
    );
    final previewStyle =
        ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final chipStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        key: Key('pattern_detail_moment_row_$index'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  moment.dateTimeLabel,
                  key: Key('pattern_detail_moment_date_$index'),
                  style: labelStyle,
                ),
              ),
              Container(
                key: Key('pattern_detail_moment_chip_$index'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  moment.statusChipLabel,
                  style: chipStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            moment.previewText,
            key: Key('pattern_detail_moment_preview_$index'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: previewStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          EntryImportanceButton(
            entryId: moment.entryId,
            source: 'pattern_detail_sheet',
            entryCount: widget.entryCount,
            compact: true,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
