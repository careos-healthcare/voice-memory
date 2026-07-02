import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/archive_summary_copy.dart';
import '../../features/early_archive/archive_summary_model.dart';
import '../../features/early_archive/archive_watching_engine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'archive_watching_micro_state.dart';

/// Unified archive overview — one surface for repeat, loop, change, and help.
class ArchiveSummaryCard extends StatelessWidget {
  const ArchiveSummaryCard({
    super.key,
    required this.summary,
    required this.showRecordNextCta,
    this.watching,
    this.onRecordNext,
  });

  final ArchiveSummaryResult summary;
  final bool showRecordNextCta;
  final ArchiveWatchingResult? watching;
  final VoidCallback? onRecordNext;

  @override
  Widget build(BuildContext context) {
    final sectionLabelStyle = ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final secondaryStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final unknownStyle = secondaryStyle.copyWith(fontStyle: FontStyle.italic);
    final evidenceStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Container(
      key: const Key('archive_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary.title,
            key: const Key('archive_summary_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveSummaryCopy.promise,
            key: const Key('archive_summary_promise'),
            style: secondaryStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SectionBlock(
            label: ArchiveSummaryCopy.keepsRepeatingLabel,
            labelKey: 'archive_summary_keeps_repeating_label',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final line in summary.keepsRepeating.bodyLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      line,
                      key: Key('archive_summary_keeps_repeating_$line'),
                      style: summary.keepsRepeating.isFallback
                          ? unknownStyle
                          : bodyStyle,
                    ),
                  ),
                for (final phrase in summary.keepsRepeating.evidencePhrases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      phrase,
                      key: Key('archive_summary_repeat_evidence_$phrase'),
                      style: evidenceStyle,
                    ),
                  ),
              ],
            ),
          ),
          if (summary.hasLoopForming) ...[
            const SizedBox(height: AppSpacing.sm),
            _SectionBlock(
              label: ArchiveSummaryCopy.loopFormingLabel,
              labelKey: 'archive_summary_loop_forming_label',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final row in summary.loopRows) ...[
                    Text(
                      row.label,
                      key: Key('archive_summary_loop_label_${row.sectionId.name}'),
                      style: sectionLabelStyle.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.displayText,
                      key: Key('archive_summary_loop_body_${row.sectionId.name}'),
                      style: row.isKnown ? bodyStyle : unknownStyle,
                    ),
                    if (row != summary.loopRows.last)
                      const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _SectionBlock(
            label: ArchiveSummaryCopy.changingLabel,
            labelKey: 'archive_summary_changing_label',
            child: Text(
              summary.changingLine,
              key: const Key('archive_summary_changing_body'),
              style: summary.changingIsFallback ? unknownStyle : bodyStyle,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SectionBlock(
            label: ArchiveSummaryCopy.whatHelpsLabel,
            labelKey: 'archive_summary_what_helps_label',
            child: Text(
              summary.whatHelpsLine,
              key: const Key('archive_summary_what_helps_body'),
              style: summary.whatHelpsIsFallback ? unknownStyle : bodyStyle,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SectionBlock(
            label: ArchiveSummaryCopy.recordNextLabel,
            labelKey: 'archive_summary_record_next_label',
            child: Text(
              summary.recordNext.prompt,
              key: const Key('archive_summary_record_next_prompt'),
              style: secondaryStyle,
            ),
          ),
          if (watching != null) ArchiveWatchingMicroState(watching: watching!),
          if (showRecordNextCta && onRecordNext != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('archive_summary_record_cta'),
                onPressed: onRecordNext,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(ArchiveSummaryCopy.recordNextCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.label,
    required this.labelKey,
    required this.child,
  });

  final String label;
  final String labelKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          key: Key(labelKey),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
