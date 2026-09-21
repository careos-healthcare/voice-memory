import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_relative_date.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Archive-home card for the cached 7-day trend analysis report.
///
/// Reads only [WeeklySelfReflectionReport] display fields — never `metadata`.
class TrendPatternSummaryCard extends StatefulWidget {
  const TrendPatternSummaryCard({
    super.key,
    this.reportLoader,
  });

  static const Key cardKey = Key('trend_pattern_summary_card');
  static const Key emptyKey = Key('trend_pattern_summary_empty');
  static const Key loadingKey = Key('trend_pattern_summary_loading');

  static const String title = "This week's patterns";
  static const String emptyCopy = 'Not enough recent entries yet';
  static const int minReflections = 3;

  /// Test-only cached-report override — never set in production code.
  @visibleForTesting
  final Future<WeeklySelfReflectionReport?>? reportLoader;

  @override
  State<TrendPatternSummaryCard> createState() =>
      _TrendPatternSummaryCardState();
}

class _TrendPatternSummaryCardState extends State<TrendPatternSummaryCard> {
  WeeklySelfReflectionReport? _report;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    if (!V1CapabilityRegistry.trendPatternSummary) {
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    WeeklySelfReflectionReport? report;
    try {
      report = await _loadCachedReport();
    } on Object {
      report = null;
    }
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<WeeklySelfReflectionReport?> _loadCachedReport() async {
    final injected = widget.reportLoader;
    if (injected != null) return injected;
    if (!AppServices.isInitialized) return null;
    final service = await AppServices.instance.trendAnalysisService;
    return service.getCachedReport(TrendAnalysisWindow.sevenDay);
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.trendPatternSummary) {
      return const SizedBox.shrink();
    }

    final report = _report;
    final showEmpty = !_loading &&
        (report == null ||
            report.reflectionCount < TrendPatternSummaryCard.minReflections);

    return Padding(
      padding: EdgeInsets.only(bottom: ArchiveResponsiveLayout.gap(context)),
      child: Material(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warmBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: _loading
                ? const Center(
                    key: TrendPatternSummaryCard.loadingKey,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : showEmpty
                    ? _EmptyState()
                    : _ReportBody(report: report!),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      key: TrendPatternSummaryCard.emptyKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TrendPatternSummaryCard.title,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          TrendPatternSummaryCard.emptyCopy,
          style: ArchiveMobileTypography.listSubtitle(context).copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final WeeklySelfReflectionReport report;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.listTitle(context);
    final bodyStyle = ArchiveMobileTypography.body(context).copyWith(
      color: AppColors.textPrimary,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textMuted,
    );
    final detailStyle = ArchiveMobileTypography.listSubtitle(context).copyWith(
      color: AppColors.textMuted,
    );

    final summary = report.summary.trim();
    final entryLabel = report.reflectionCount == 1 ? 'entry' : 'entries';
    final generatedLabel =
        'Updated ${formatArchiveRelativeUpdate(report.generatedAt)}';

    return Column(
      key: TrendPatternSummaryCard.cardKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TrendPatternSummaryCard.title, style: titleStyle),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(summary, style: bodyStyle),
        ],
        if (report.emotionalShifts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('What shifted', style: labelStyle),
          const SizedBox(height: AppSpacing.xs),
          for (final shift in report.emotionalShifts) ...[
            if (shift.headline.trim().isNotEmpty)
              Text(shift.headline.trim(), style: bodyStyle),
            if (shift.detail.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(shift.detail.trim(), style: detailStyle),
            ],
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
        if (report.cognitiveLoops.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Repeating', style: labelStyle),
          const SizedBox(height: AppSpacing.xs),
          for (final loop in report.cognitiveLoops) ...[
            Text(
              _loopHeadline(loop),
              style: bodyStyle,
            ),
            if ((loop.detail ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(loop.detail!.trim(), style: detailStyle),
            ],
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${report.reflectionCount} $entryLabel · $generatedLabel',
          style: detailStyle,
        ),
      ],
    );
  }

  String _loopHeadline(CognitiveLoopLine loop) {
    final pattern = loop.pattern.trim();
    final times = loop.occurrences == 1 ? '1 time' : '${loop.occurrences} times';
    if (pattern.isEmpty) return times;
    return '$pattern · $times';
  }
}
