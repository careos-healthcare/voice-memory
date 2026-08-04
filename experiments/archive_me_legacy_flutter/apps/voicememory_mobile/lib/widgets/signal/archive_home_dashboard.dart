import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/signal_archive/signal_archive_navigation.dart';
import '../../features/signal_archive/signal_archive_snapshot.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact dashboard — current signal, evidence progress, quick links.
class ArchiveHomeDashboard extends StatelessWidget {
  const ArchiveHomeDashboard({
    super.key,
    required this.snapshot,
    this.onOpenPatterns,
  });

  final SignalArchiveSnapshot snapshot;
  final VoidCallback? onOpenPatterns;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final signal = snapshot.selectedSignal;

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.archiveHomeTitle,
            style: ArchiveMobileTypography.archiveSurfaceTitle(context)
                .copyWith(
                  fontSize: ArchiveResponsiveLayout.isTabletOrDesktop(context)
                      ? 28
                      : 26,
                ),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.archiveHomeLead,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          if (signal != null) ...[
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.archiveHomeWatching,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              signal.title,
              style: ArchiveMobileTypography.listTitle(context),
            ),
            if (signal.strengthLabel.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                signal.strengthLabel,
                style: ArchiveMobileTypography.responsiveBody(context),
              ),
            ],
            if (signal.nextPrompt.trim().isNotEmpty) ...[
              SizedBox(height: gap),
              Text(
                ConsumerUiCopy.signalDetailRecordNext,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                signal.nextPrompt,
                style: ArchiveMobileTypography.explanationBody(context),
              ),
            ],
          ],
          SizedBox(height: gap),
          Text(
            '${ConsumerUiCopy.archiveHomeEvidenceCount}: ${snapshot.evidenceCount}',
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          if (snapshot.hypothesis?.hasEnoughData == true) ...[
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.archiveWatchingHypothesisLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              snapshot.hypothesis!.patternMightBe,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          if (signal == null && snapshot.reflectionCount == 0) ...[
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.archiveHomeSharpen,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ] else if (signal != null && snapshot.evidenceCount < 2) ...[
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.archiveHomeSharpen,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          SizedBox(height: gap),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (signal != null)
                OutlinedButton(
                  onPressed: () =>
                      SignalArchiveNavigation.openSignalDetail(context),
                  child: Text(ConsumerUiCopy.archiveHomeOpenDetail),
                ),
              if (signal != null)
                OutlinedButton(
                  onPressed: () =>
                      SignalArchiveNavigation.openEvidenceTrail(context),
                  child: Text(ConsumerUiCopy.archiveHomeOpenTrail),
                ),
              if (onOpenPatterns != null)
                OutlinedButton(
                  onPressed: onOpenPatterns,
                  child: Text(ConsumerUiCopy.archiveHomeOpenPatterns),
                ),
              FilledButton(
                onPressed: () => SignalArchiveNavigation.recordNextEvidence(
                  context,
                  prompt: signal?.nextPrompt,
                ),
                child: Text(ConsumerUiCopy.archiveHomeRecordEvidence),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
