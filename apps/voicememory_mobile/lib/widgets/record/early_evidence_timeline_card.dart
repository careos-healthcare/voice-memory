import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/early_archive/early_archive_proof_analytics.dart';
import '../../features/early_archive/early_archive_insight_feedback_models.dart';
import '../../features/early_archive/early_archive_insight_quality_engine.dart';
import '../../features/early_archive/early_evidence_timeline_engine.dart';
import '../../features/early_archive/early_first_signal_copy.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'early_archive_insight_feedback_row.dart';
import 'early_archive_insight_why_section.dart';

/// Sequential early evidence timeline — repeat, trigger, softening, helpful action.
class EarlyEvidenceTimelineCard extends StatelessWidget {
  const EarlyEvidenceTimelineCard({
    super.key,
    required this.timeline,
    this.compact = false,
    this.onRecordWhatHelped,
    this.analyticsSurface,
    this.entryCount,
    this.isSample = false,
    this.entriesForWhy,
  });

  final EarlyEvidenceTimeline timeline;
  final bool compact;
  final VoidCallback? onRecordWhatHelped;
  final String? analyticsSurface;
  final int? entryCount;
  final bool isSample;
  final List<JournalEntry>? entriesForWhy;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _railColor = Color(0xFF6B8F71);

  static String _chipLabel(EarlyEvidenceTimelineItemKind kind) => switch (kind) {
        EarlyEvidenceTimelineItemKind.repeatConfirmed => 'Repeat',
        EarlyEvidenceTimelineItemKind.triggerCaptured => 'Trigger',
        EarlyEvidenceTimelineItemKind.softerReturn => 'Change',
        EarlyEvidenceTimelineItemKind.helpfulAction => 'Helped',
      };

  @override
  Widget build(BuildContext context) {
    final surface = analyticsSurface;
    final count = entryCount;
    if (!isSample && surface != null && count != null) {
      EarlyArchiveProofAnalytics.timelineSeen(
        entryCount: count,
        surface: surface,
        milestoneCount: timeline.items.length,
        hasRealTimeline: true,
        compact: compact,
      );
    }
    final gap = compact ? AppSpacing.sm : ArchiveResponsiveLayout.gap(context);
    final padding = compact
        ? const EdgeInsets.all(AppSpacing.sm)
        : ArchiveResponsiveLayout.cardInsets(context);
    final whyReasons = !isSample && entriesForWhy != null
        ? EarlyArchiveInsightQualityEngine.whyReasonsFor(
            insightType: EarlyArchiveInsightType.timeline,
            entries: entriesForWhy!,
          )
        : const <String>[];

    return Container(
      key: Key('early_evidence_timeline_card_${compact ? 'compact' : 'full'}'),
      width: double.infinity,
      padding: padding,
      decoration: VoiceMemoryCards.standard(background: _warmSurface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderSection(
            title: timeline.title,
            subtitle: compact ? null : timeline.subtitle,
            compact: compact,
          ),
          if (timeline.evidencePhrases.isNotEmpty) ...[
            SizedBox(height: gap),
            Text(
              EarlyFirstSignalCopy.evidenceHeading,
              key: const Key('early_evidence_timeline_evidence_heading'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              key: const Key('early_evidence_timeline_evidence_phrases'),
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final phrase in timeline.evidencePhrases)
                  Chip(
                    key: ValueKey('early_evidence_timeline_evidence_phrase_$phrase'),
                    label: Text(phrase),
                    backgroundColor: const Color(0xFFF4F7F4),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    labelStyle: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ],
          if (!compact) ...[
            SizedBox(height: gap),
            _MilestoneChipTrail(items: timeline.items),
          ],
          SizedBox(height: gap),
          _EvidenceChain(
            items: timeline.items,
            compact: compact,
          ),
          if (!isSample && surface != null && count != null) ...[
            EarlyArchiveInsightWhySection(
              reasons: whyReasons,
              insightKey: 'timeline',
            ),
            EarlyArchiveInsightFeedbackRow(
              insightType: EarlyArchiveInsightType.timeline,
              surface: surface!,
              entryCount: count!,
            ),
          ],
          if (onRecordWhatHelped != null &&
              timeline.showsSofterReturn &&
              !timeline.showsHelpfulAction) ...[
            SizedBox(height: gap),
            OutlinedButton(
              key: const Key('early_evidence_timeline_record_what_helped_cta'),
              onPressed: () {
                if (surface != null && count != null) {
                  EarlyArchiveProofAnalytics.helpfulActionPromptTapped(
                    entryCount: count,
                    surface: surface,
                  );
                }
                onRecordWhatHelped!();
              },
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

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = compact
        ? ArchiveMobileTypography.responsiveSectionTitle(context).copyWith(
            fontSize: 17,
            height: 1.25,
          )
        : ArchiveMobileTypography.responsiveSectionTitle(context).copyWith(
            fontSize: ArchiveResponsiveLayout.isTabletOrDesktop(context)
                ? 22
                : 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.25,
            color: AppColors.textPrimary,
          );
    final subtitleStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
      fontSize: ArchiveResponsiveLayout.isTabletOrDesktop(context) ? 17 : 16,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: const Key('early_evidence_timeline_title'),
          style: titleStyle,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            key: const Key('early_evidence_timeline_subtitle'),
            style: subtitleStyle,
          ),
        ],
      ],
    );
  }
}

class _MilestoneChipTrail extends StatelessWidget {
  const _MilestoneChipTrail({required this.items});

  final List<EarlyEvidenceTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('early_evidence_timeline_chip_trail'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Text(
                '·',
                key: Key('early_evidence_timeline_chip_sep_${items[i].kind.name}'),
                style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            _MilestoneChip(
              label: EarlyEvidenceTimelineCard._chipLabel(items[i].kind),
              kind: items[i].kind,
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({
    required this.label,
    required this.kind,
  });

  final String label;
  final EarlyEvidenceTimelineItemKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('early_evidence_timeline_chip_${kind.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontSize: 12,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _EvidenceChain extends StatelessWidget {
  const _EvidenceChain({
    required this.items,
    required this.compact,
  });

  final List<EarlyEvidenceTimelineItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final itemTitleStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: compact ? 14 : 15,
      height: 1.3,
    );
    final itemBodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
      fontSize: compact ? 13 : 14,
    );
    final chipLabelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary.withValues(alpha: 0.85),
      fontSize: 11,
      letterSpacing: 0.15,
    );
    final segmentHeight = compact ? 24.0 : 32.0;
    const railWidth = 2.0;
    const dotSize = 8.0;

    return Column(
      key: const Key('early_evidence_timeline_chain'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        key: Key(
                          'early_evidence_timeline_dot_${items[i].kind.name}',
                        ),
                        width: dotSize,
                        height: dotSize,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: EarlyEvidenceTimelineCard._railColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: EarlyEvidenceTimelineCard._railColor
                                .withValues(alpha: 0.35),
                            width: 3,
                          ),
                        ),
                      ),
                      if (i < items.length - 1)
                        Expanded(
                          child: Container(
                            width: railWidth,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: EarlyEvidenceTimelineCard._railColor
                                .withValues(alpha: 0.22),
                          ),
                        )
                      else
                        SizedBox(height: segmentHeight),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < items.length - 1
                          ? (compact ? AppSpacing.sm : AppSpacing.md)
                          : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              EarlyEvidenceTimelineCard._chipLabel(items[i].kind),
                              key: Key(
                                'early_evidence_timeline_row_chip_${items[i].kind.name}',
                              ),
                              style: chipLabelStyle,
                            ),
                          ),
                        Text(
                          items[i].title,
                          key: Key(
                            'early_evidence_timeline_item_title_${items[i].kind.name}',
                          ),
                          style: itemTitleStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].body,
                          key: Key(
                            'early_evidence_timeline_item_body_${items[i].kind.name}',
                          ),
                          style: itemBodyStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
