import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/screenshot_mode.dart';
import '../../../../design/archive_mobile_typography.dart';
import '../../../../services/app_services.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../data/repositories/curiosity_reaction_repository.dart';
import '../../services/productivity_report_engine.dart';
import '../../weekly_productivity_report_copy.dart';

/// Compact account/profile entry into the weekly curiosity check-in report.
class WeeklyGrowthPreviewCard extends StatefulWidget {
  const WeeklyGrowthPreviewCard({
    super.key,
    this.engine,
    this.initialReport,
  });

  /// Test hook to render a fixed report without async loading.
  const WeeklyGrowthPreviewCard.test({
    super.key,
    required WeeklyProductivityReport report,
  })  : engine = null,
        initialReport = report;

  final ProductivityReportEngine? engine;
  final WeeklyProductivityReport? initialReport;

  @override
  State<WeeklyGrowthPreviewCard> createState() =>
      _WeeklyGrowthPreviewCardState();
}

class _WeeklyGrowthPreviewCardState extends State<WeeklyGrowthPreviewCard> {
  WeeklyProductivityReport? _report;
  var _loading = true;

  ProductivityReportEngine get _engine =>
      widget.engine ??
      ProductivityReportEngine(LocalCuriosityReactionRepository.instance());

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialReport;
    if (seeded != null) {
      _report = seeded;
      _loading = false;
      return;
    }
    unawaited(_loadReport());
  }

  Future<void> _loadReport() async {
    if (ScreenshotMode.enabled || !AppServices.isInitialized) {
      if (!mounted) return;
      setState(() {
        _report = const WeeklyProductivityReport(
          totalReactions: 0,
          reactionBreakdown: {},
          stuckAnchors: [],
          momentumAnchors: [],
        );
        _loading = false;
      });
      return;
    }

    final report = await _engine.generateWeeklyReport();
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  String get _message {
    if (_loading) {
      return WeeklyProductivityReportCopy.previewEmptyMessage;
    }
    final total = _report?.totalReactions ?? 0;
    if (total == 0) {
      return WeeklyProductivityReportCopy.previewEmptyMessage;
    }
    return WeeklyProductivityReportCopy.previewMessage(total);
  }

  void _openReport() {
    context.push(WeeklyProductivityReportCopy.route);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _message,
      child: Material(
        key: const Key('weekly_growth_preview_card'),
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _openReport,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _message,
                    key: const Key('weekly_growth_preview_message'),
                    style: ArchiveMobileTypography.listSubtitle(context),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
