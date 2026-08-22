import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Developer X-Ray panel — local RAG context and scoring breakdown.
class XRayPanel extends StatelessWidget {
  const XRayPanel({
    required this.inspection,
    required this.theoryStatement,
    super.key,
  });

  final TheoryRankingInspection inspection;
  final String theoryStatement;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final confidence = inspection.confidenceBreakdown;
    final rank = inspection.rankBreakdown;

    return ListView(
      key: const Key('xray_panel'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Text(
          'X-Ray',
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          theoryStatement,
          style: ArchiveMobileTypography.explanationBody(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionTitle(context, 'Final scores'),
        _metricRow(context, 'Confidence', '${inspection.finalConfidencePercent}%'),
        _metricRow(context, 'Rank score', '${inspection.finalRankScore}'),
        const SizedBox(height: AppSpacing.lg),
        _sectionTitle(context, 'Confidence breakdown'),
        _scoreLine(context, 'Volume', confidence.volumePoints, positive: true),
        _scoreLine(context, 'Consistency', confidence.consistencyPoints, positive: true),
        _scoreLine(context, 'Recency', confidence.recencyPoints, positive: true),
        _scoreLine(context, 'Contradiction penalty', confidence.contradictionPenalty, positive: false),
        _scoreLine(context, 'Counter-evidence penalty', confidence.counterPenalty, positive: false),
        if (confidence.lowEvidenceMultiplierApplied)
          _modifierChip(context, '×0.6 low evidence (<3 mentions)'),
        if (confidence.staleMultiplierApplied)
          _modifierChip(context, '×0.75 stale (no recent support)'),
        _metricRow(
          context,
          'Raw before modifiers',
          '${confidence.rawTotalBeforeModifiers}',
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionTitle(context, 'Rank breakdown'),
        _scoreLine(context, 'Volume', rank.volumePoints, positive: true),
        _scoreLine(context, 'Consistency', rank.consistencyPoints, positive: true),
        _scoreLine(context, 'Recency', rank.recencyPoints, positive: true),
        _scoreLine(context, 'Contradiction relevance', rank.contradictionPoints, positive: true),
        _scoreLine(context, 'Surprise signal', rank.surprisePoints, positive: true),
        _scoreLine(context, 'Counter quality', rank.counterQualityPoints, positive: true),
        const SizedBox(height: AppSpacing.lg),
        _sectionTitle(context, 'Retrieved context'),
        if (inspection.retrievedChunks.isEmpty)
          Text(
            'No matching entries found for this pattern.',
            style: ArchiveMobileTypography.responsiveHelper(context),
          )
        else
          ...inspection.retrievedChunks.map((chunk) => _chunkTile(context, chunk)),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: ArchiveMobileTypography.cardLabel(context)),
    );
  }

  Widget _metricRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: ArchiveMobileTypography.explanationBody(context)),
          ),
          Text(
            value,
            style: ArchiveMobileTypography.listTitle(context).copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _scoreLine(
    BuildContext context,
    String label,
    int points, {
    required bool positive,
  }) {
    final prefix = positive ? '+' : '−';
    final color = positive ? AppColors.accentSecondary : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: ArchiveMobileTypography.explanationBody(context)),
          ),
          Text(
            '$prefix$points',
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modifierChip(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warmBorder),
        ),
        child: Text(
          label,
          style: ArchiveMobileTypography.responsiveHelper(context),
        ),
      ),
    );
  }

  Widget _chunkTile(BuildContext context, TheoryRetrievalChunk chunk) {
    final dateLabel = chunk.recordedAt == null
        ? chunk.entryId
        : _dateFormat.format(chunk.recordedAt!.toLocal());

    return Container(
      key: Key('xray_chunk_${chunk.entryId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _roleChip(context, chunk.role),
              const Spacer(),
              Text(dateLabel, style: ArchiveMobileTypography.responsiveHelper(context)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '“${chunk.excerpt}”',
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (chunk.keywordOverlap != null)
                _statChip(context, 'Keyword overlap', '${chunk.keywordOverlap}'),
              if (chunk.vectorSimilarity != null)
                _statChip(
                  context,
                  'Vector sim',
                  chunk.vectorSimilarity!.toStringAsFixed(3),
                ),
              if (chunk.hybridScore != null)
                _statChip(
                  context,
                  'Hybrid RRF',
                  chunk.hybridScore!.toStringAsFixed(4),
                ),
              if (chunk.keywordRank != null)
                _statChip(context, 'Keyword rank', '#${chunk.keywordRank}'),
              if (chunk.vectorRank != null)
                _statChip(context, 'Vector rank', '#${chunk.vectorRank}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleChip(BuildContext context, TheoryRetrievalRole role) {
    final label = switch (role) {
      TheoryRetrievalRole.supporting => 'Supporting',
      TheoryRetrievalRole.counter => 'Counter',
      TheoryRetrievalRole.hybrid => 'Hybrid hit',
    };
    final color = switch (role) {
      TheoryRetrievalRole.supporting => AppColors.accentSecondary,
      TheoryRetrievalRole.counter => AppColors.warning,
      TheoryRetrievalRole.hybrid => AppColors.accentPrimary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statChip(BuildContext context, String label, String value) {
    return Text(
      '$label: $value',
      style: ArchiveMobileTypography.responsiveHelper(context),
    );
  }
}
