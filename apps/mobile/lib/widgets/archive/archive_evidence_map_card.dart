import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact card showing usable archive moments by context.
class ArchiveEvidenceMapCard extends StatelessWidget {
  const ArchiveEvidenceMapCard({required this.map, super.key, this.onRowTap});

  final ArchiveEvidenceMap map;
  final ValueChanged<String>? onRowTap;

  @override
  Widget build(BuildContext context) {
    if (!map.showCard) return const SizedBox.shrink();

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final maxCount = map.rows.isEmpty
        ? 0
        : map.rows.map((row) => row.count).reduce((a, b) => a > b ? a : b);

    return Container(
      key: const Key('archive_evidence_map_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            map.title,
            key: const Key('archive_evidence_map_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            map.subtitle,
            key: const Key('archive_evidence_map_subtitle'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          if (map.rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final row in map.rows) ...[
              Material(
                color: AppColors.transparent,
                child: InkWell(
                  key: Key('archive_evidence_map_row_tap_${row.rowId}'),
                  onTap: onRowTap == null ? null : () => onRowTap!(row.rowId),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${row.label}: '
                                '${ArchiveEvidenceMapEngine.momentCountLabel(row.count)}',
                                key: Key(
                                  'archive_evidence_map_row_${row.rowId}',
                                ),
                                style: bodyStyle,
                              ),
                            ),
                            if (onRowTap != null)
                              Icon(
                                Icons.chevron_right,
                                key: Key(
                                  'archive_evidence_map_row_chevron_${row.rowId}',
                                ),
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                          ],
                        ),
                        if (maxCount > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              key: Key('archive_evidence_map_bar_${row.rowId}'),
                              value: row.count / maxCount,
                              minHeight: 6,
                              backgroundColor: AppColors.backgroundPrimary,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
          if (map.strongestContextLine case final strongest?) ...[
            Text(
              VisibleArchiveProofCopy.archiveEvidenceMapStrongestLabel,
              key: const Key('archive_evidence_map_strongest_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              strongest,
              key: const Key('archive_evidence_map_strongest_line'),
              style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (map.thinContextsLine case final thin?) ...[
            Text(
              VisibleArchiveProofCopy.archiveEvidenceMapThinLabel,
              key: const Key('archive_evidence_map_thin_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              thin,
              key: const Key('archive_evidence_map_thin_line'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (map.untaggedLine case final untagged?) ...[
            Text(
              VisibleArchiveProofCopy.archiveEvidenceMapUntaggedLabel,
              key: const Key('archive_evidence_map_untagged_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              untagged,
              key: const Key('archive_evidence_map_untagged_line'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (map.nextActionLine case final nextAction?) ...[
            Text(
              VisibleArchiveProofCopy.archiveEvidenceMapNextLabel,
              key: const Key('archive_evidence_map_next_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              nextAction,
              key: const Key('archive_evidence_map_next_line'),
              style: bodyStyle,
            ),
          ],
          if (map.excludedNote case final excluded?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              excluded,
              key: const Key('archive_evidence_map_excluded_note'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}