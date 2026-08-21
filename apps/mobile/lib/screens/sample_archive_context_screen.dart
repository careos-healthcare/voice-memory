import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_entries.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

/// Read-only Work/Home context drilldown for sample archive demo paths only.
class SampleArchiveContextScreen extends StatelessWidget {
  const SampleArchiveContextScreen({required this.contextTagId, super.key});

  final String contextTagId;

  @override
  Widget build(BuildContext context) {
    final entries = SampleArchiveEntries.build();
    assert(entries.every(SampleArchiveMode.isSampleEntry));
    final drilldown = ArchiveEvidenceMapEngine.buildContextDrilldown(
      entries: entries,
      contextTagId: contextTagId,
    );

    return PushedScreenShell(
      title: drilldown.title,
      doneLabel: SampleArchiveCopy.exitDone,
      fallbackRoute: '/sample-archive',
      body: ListView(
        key: const Key('sample_archive_context_screen'),
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          Container(
            key: const Key('sample_archive_context_banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: VoiceMemoryCards.standard(
              background: AppColors.backgroundSecondary,
            ),
            child: Text(
              SampleArchiveCopy.sampleContextBanner,
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            drilldown.subtitle,
            key: const Key('sample_archive_context_subtitle'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (drilldown.isEmpty)
            Text(
              drilldown.emptyBody,
              key: const Key('sample_archive_context_empty'),
              style: ArchiveMobileTypography.explanationBody(context),
            )
          else
            for (final entry in drilldown.entries) ...[
              Container(
                key: Key('sample_archive_context_item_${entry.id}'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: VoiceMemoryCards.standard(
                  background: AppColors.backgroundSecondary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      formatUserFacingDate(entry.createdAt),
                      style: ArchiveMobileTypography.cardLabel(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      SampleArchiveCopy.sampleContextExampleLabel,
                      style: ArchiveMobileTypography.cardLabel(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      timelineEntryTitle(entry),
                      style: ArchiveMobileTypography.listTitle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      postSaveRecordedSummary(entry),
                      style: ArchiveMobileTypography.listSubtitle(context),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}