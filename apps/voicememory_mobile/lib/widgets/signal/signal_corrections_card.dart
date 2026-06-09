import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/signal_archive/signal_corrections_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Corrections the user made — trust surface, not shame.
class SignalCorrectionsCard extends StatelessWidget {
  const SignalCorrectionsCard({
    super.key,
    required this.corrections,
  });

  final SignalCorrectionView corrections;

  @override
  Widget build(BuildContext context) {
    if (!corrections.hasCorrections) return const SizedBox.shrink();

    final gap = ArchiveResponsiveLayout.gap(context);

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.signalCorrectionsTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          if (corrections.rejectedTitles.isNotEmpty) ...[
            Text(
              ConsumerUiCopy.signalCorrectionsRejected,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...corrections.rejectedTitles.map(
              (title) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  title,
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (corrections.selectedAlternativeTitle?.trim().isNotEmpty == true) ...[
            Text(
              ConsumerUiCopy.signalCorrectionsSelected,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              corrections.selectedAlternativeTitle!,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            ConsumerUiCopy.signalCorrectionsNote,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.signalCorrectionsFeedbackNote,
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
        ],
      ),
    );
  }
}
