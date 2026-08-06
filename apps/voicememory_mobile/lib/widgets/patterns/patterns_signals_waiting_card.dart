import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/post_save_insight/selected_signal_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Patterns tab — signals waiting for confirmation before a full pattern.
class PatternsSignalsWaitingCard extends StatelessWidget {
  const PatternsSignalsWaitingCard({
    super.key,
    required this.selected,
    required this.reflectionCount,
    this.nextPrompt,
    this.onRecord,
    this.onViewDetail,
  });

  final SelectedSignalRecord selected;
  final int reflectionCount;
  final String? nextPrompt;
  final VoidCallback? onRecord;
  final VoidCallback? onViewDetail;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final progress = ConsumerUiCopy.postSaveInsightMomentsProgress.replaceAll(
      '{count}',
      reflectionCount.clamp(0, 3).toString(),
    );

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.patternsSignalsWaitingTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(progress, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          _SignalRow(record: selected),
          if (onViewDetail != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewDetail,
                child: Text(ConsumerUiCopy.signalDetailViewSignal),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            ConsumerUiCopy.patternsWatchingSignalTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.patternsWatchingSignalBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          if (nextPrompt != null && nextPrompt!.trim().isNotEmpty) ...[
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.patternsSignalsWaitingClarity,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              nextPrompt!,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          if (onRecord != null) ...[
            SizedBox(height: gap),
            FilledButton(
              onPressed: onRecord,
              child: Text(ConsumerUiCopy.postSaveRecordAnother),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.record});

  final SelectedSignalRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.title,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              if (record.strengthLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.strengthLabel,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                ),
            ],
          ),
          if (record.whySuggested?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              record.whySuggested!,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
        ],
      ),
    );
  }
}
