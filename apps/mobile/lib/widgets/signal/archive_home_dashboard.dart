import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_archive_navigation.dart';
import 'package:archiveme_mobile/features/signal_archive/signal_archive_snapshot.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact dashboard — current signal, evidence progress, quick links.
class ArchiveHomeDashboard extends StatelessWidget {
  const ArchiveHomeDashboard({
    required this.snapshot, super.key,
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
                  child: const Text(ConsumerUiCopy.archiveHomeOpenDetail),
                ),
              if (signal != null)
                OutlinedButton(
                  onPressed: () =>
                      SignalArchiveNavigation.openEvidenceTrail(context),
                  child: const Text(ConsumerUiCopy.archiveHomeOpenTrail),
                ),
              if (onOpenPatterns != null)
                OutlinedButton(
                  onPressed: onOpenPatterns,
                  child: const Text(ConsumerUiCopy.archiveHomeOpenPatterns),
                ),
              FilledButton(
                onPressed: () => SignalArchiveNavigation.recordNextEvidence(
                  context,
                  prompt: signal?.nextPrompt,
                ),
                child: const Text(ConsumerUiCopy.archiveHomeRecordEvidence),
              ),
            ],
          ),
        ],
      ),
    );
  }
}