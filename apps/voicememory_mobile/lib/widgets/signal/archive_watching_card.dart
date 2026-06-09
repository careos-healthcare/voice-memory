import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/signal_archive/signal_archive_navigation.dart';
import '../../features/signal_archive/signal_archive_snapshot.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Today's watch list — up to 3 active archive signals on Record and Patterns.
class ArchiveWatchingCard extends StatelessWidget {
  const ArchiveWatchingCard({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final SignalArchiveSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final rows = _watchRows();

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.archiveWatchingTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          if (rows.isEmpty)
            Text(
              ConsumerUiCopy.archiveWatchingEmpty,
              style: ArchiveMobileTypography.explanationBody(context),
            )
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _WatchRow(row: row),
              ),
            ),
          if (rows.isNotEmpty && !compact) ...[
            FilledButton(
              onPressed: () => SignalArchiveNavigation.recordNextEvidence(
                context,
                prompt: snapshot.selectedSignal?.nextPrompt,
              ),
              child: Text(ConsumerUiCopy.archiveWatchingRecordEvidence),
            ),
          ],
        ],
      ),
    );
  }

  List<_WatchRowModel> _watchRows() {
    final out = <_WatchRowModel>[];
    final signal = snapshot.selectedSignal;
    if (signal != null) {
      out.add(
        _WatchRowModel(
          title: signal.title,
          strengthLabel: signal.strengthLabel,
          nextPrompt: signal.nextPrompt,
          kind: ConsumerUiCopy.archiveHomeWatching,
        ),
      );
    }
    final hypothesis = snapshot.hypothesis;
    if (hypothesis != null && hypothesis.hasEnoughData && out.length < 3) {
      out.add(
        _WatchRowModel(
          title: hypothesis.patternMightBe,
          strengthLabel: ConsumerUiCopy.archiveWatchingHypothesisLabel,
          nextPrompt: hypothesis.watchNext,
          kind: ConsumerUiCopy.archiveWatchingHypothesisLabel,
        ),
      );
    }
    if (signal != null &&
        signal.nextPrompt.trim().isNotEmpty &&
        out.length < 3 &&
        !out.any((r) => r.kind == ConsumerUiCopy.signalEvidenceNextPrompt)) {
      out.add(
        _WatchRowModel(
          title: ConsumerUiCopy.signalEvidenceNextPrompt,
          strengthLabel: signal.strengthLabel,
          nextPrompt: signal.nextPrompt,
          kind: ConsumerUiCopy.signalEvidenceNextPrompt,
        ),
      );
    }
    return out.take(3).toList();
  }
}

class _WatchRowModel {
  const _WatchRowModel({
    required this.title,
    required this.strengthLabel,
    required this.nextPrompt,
    required this.kind,
  });

  final String title;
  final String strengthLabel;
  final String nextPrompt;
  final String kind;
}

class _WatchRow extends StatelessWidget {
  const _WatchRow({required this.row});

  final _WatchRowModel row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.title, style: ArchiveMobileTypography.listTitle(context)),
              ),
              if (row.strengthLabel.isNotEmpty)
                Text(
                  row.strengthLabel,
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
            ],
          ),
          if (row.nextPrompt.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              row.nextPrompt,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => SignalArchiveNavigation.recordNextEvidence(
                context,
                prompt: row.nextPrompt,
              ),
              child: Text(ConsumerUiCopy.archiveWatchingRecordEvidence),
            ),
          ),
        ],
      ),
    );
  }
}
