import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/archive_mobile_typography.dart';
import '../../../features/share/archive_share_actions.dart';
import '../../../services/app_services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/voicememory_cards.dart';
import '../../../widgets/pushed_screen_shell.dart';
import '../data/repositories/curiosity_reaction_repository.dart';
import '../presentation/models/telemetry_data_point.dart';
import '../../cognitive_telemetry/presentation/widgets/connected_cognitive_telemetry_trend_widget.dart';
import '../presentation/widgets/connected_clinical_telemetry_trend_widget.dart';
import '../repositories/clinical_trajectory_history_store.dart';
import '../repositories/curiosity_hook_repository.dart';
import '../services/curiosity_data_exporter.dart';
import '../services/productivity_report_engine.dart';
import '../weekly_productivity_report_copy.dart';
import '../yesterdays_snapshot_reaction.dart';

/// Seven-day rolling view of curiosity loop check-in reactions.
class WeeklyProductivityReportScreen extends StatefulWidget {
  const WeeklyProductivityReportScreen({
    super.key,
    this.engine,
    this.initialReport,
    this.initialTrajectoryPoints = const [],
    this.trajectoryHistoryStore,
    this.exporter,
    this.markdownCopyHandler,
  });

  /// Test hook to render a fixed report without async loading.
  const WeeklyProductivityReportScreen.test({
    super.key,
    required WeeklyProductivityReport report,
    this.initialTrajectoryPoints = const [],
    this.exporter,
    this.markdownCopyHandler,
  }) : engine = null,
       initialReport = report,
       trajectoryHistoryStore = null;

  final ProductivityReportEngine? engine;
  final WeeklyProductivityReport? initialReport;
  final List<TelemetryDataPoint> initialTrajectoryPoints;
  final ClinicalTrajectoryHistoryStore? trajectoryHistoryStore;
  final CuriosityDataExporter? exporter;
  final Future<void> Function(String markdown)? markdownCopyHandler;

  @override
  State<WeeklyProductivityReportScreen> createState() =>
      _WeeklyProductivityReportScreenState();
}

class _WeeklyProductivityReportScreenState
    extends State<WeeklyProductivityReportScreen> {
  WeeklyProductivityReport? _report;
  List<TelemetryDataPoint> _trajectoryPoints = const [];
  var _loading = true;
  var _exporting = false;

  ProductivityReportEngine get _engine =>
      widget.engine ??
      ProductivityReportEngine(LocalCuriosityReactionRepository.instance());

  ClinicalTrajectoryHistoryStore get _trajectoryHistoryStore =>
      widget.trajectoryHistoryStore ??
      LocalClinicalTrajectoryHistoryStore.instance();

  CuriosityDataExporter get _exporter =>
      widget.exporter ??
      CuriosityDataExporter(
        journalService: AppServices.instance.journal,
        reactionRepository: LocalCuriosityReactionRepository.instance(),
        hookRepository: LocalCuriosityHookRepository.instance(),
      );

  ({DateTime start, DateTime end}) get _exportWindow {
    final end = DateTime.now().toUtc();
    final start = end.subtract(ProductivityReportEngine.reportWindow);
    return (start: start, end: end);
  }

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialReport;
    if (seeded != null) {
      _report = seeded;
      _trajectoryPoints = widget.initialTrajectoryPoints;
      _loading = false;
      return;
    }
    unawaited(_loadReport());
  }

  Future<void> _loadReport() async {
    final results = await Future.wait([
      _engine.generateWeeklyReport(),
      _trajectoryHistoryStore.loadRecent(),
    ]);
    if (!mounted) return;
    setState(() {
      _report = results[0] as WeeklyProductivityReport;
      _trajectoryPoints = results[1] as List<TelemetryDataPoint>;
      _loading = false;
    });
  }

  Future<void> _exportMarkdownDigest() async {
    if (_exporting || (_report?.totalReactions ?? 0) == 0) return;
    setState(() => _exporting = true);
    try {
      final window = _exportWindow;
      final markdown = await _exporter.exportAsMarkdown(
        start: window.start,
        end: window.end,
      );
      final copyHandler = widget.markdownCopyHandler;
      if (copyHandler != null) {
        await copyHandler(markdown);
      } else {
        await Clipboard.setData(ClipboardData(text: markdown));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(WeeklyProductivityReportCopy.markdownCopiedToast),
          duration: const Duration(milliseconds: 400),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportRawJson() async {
    if (_exporting || (_report?.totalReactions ?? 0) == 0) return;
    setState(() => _exporting = true);
    try {
      final window = _exportWindow;
      final payload = await _exporter.exportAsJson(
        start: window.start,
        end: window.end,
      );
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      if (!mounted) return;
      final outcome = await ArchiveShareActions.shareShareText(
        context,
        text: encoded,
        subject: 'ArchiveMe curiosity loop backup',
      );
      if (!mounted) return;
      if (outcome == ArchiveShareOutcome.shared ||
          outcome == ArchiveShareOutcome.fallbackCopied) {
        ArchiveShareActions.showFeedback(
          context,
          WeeklyProductivityReportCopy.jsonSharedToast,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: WeeklyProductivityReportCopy.title,
      fallbackRoute: WeeklyProductivityReportCopy.fallbackRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, _report!),
    );
  }

  Widget _buildBody(BuildContext context, WeeklyProductivityReport report) {
    if (report.totalReactions == 0) {
      return _EmptyState(key: const Key('weekly_productivity_report_empty'));
    }

    return SingleChildScrollView(
      key: const Key('weekly_productivity_report_loaded'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroHeader(totalReactions: report.totalReactions),
          const SizedBox(height: AppSpacing.lg),
          const ConnectedCognitiveTelemetryTrendWidget(),
          if (_trajectoryPoints.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ConnectedClinicalTelemetryTrendWidget(
              key: const Key('weekly_productivity_report_trajectory_trend'),
              history: _trajectoryPoints,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _ReactionBreakdownCard(breakdown: report.reactionBreakdown),
          const SizedBox(height: AppSpacing.lg),
          _AnchorSection(
            key: const Key('weekly_productivity_report_momentum'),
            title: WeeklyProductivityReportCopy.momentumTitle,
            helper: WeeklyProductivityReportCopy.momentumHelper,
            emptyCopy: WeeklyProductivityReportCopy.momentumEmpty,
            anchors: report.momentumAnchors,
            accent: const Color(0xFFEAF6EE),
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          _AnchorSection(
            key: const Key('weekly_productivity_report_obstacles'),
            title: WeeklyProductivityReportCopy.obstaclesTitle,
            helper: WeeklyProductivityReportCopy.obstaclesHelper,
            emptyCopy: WeeklyProductivityReportCopy.obstaclesEmpty,
            anchors: report.stuckAnchors,
            accent: const Color(0xFFFFF6E8),
            icon: Icons.sync_problem_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ExportPortabilitySection(
            exporting: _exporting,
            onExportMarkdown: _exportMarkdownDigest,
            onExportJson: _exportRawJson,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_graph_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              WeeklyProductivityReportCopy.emptyTitle,
              key: const Key('weekly_productivity_report_empty_title'),
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              WeeklyProductivityReportCopy.emptyBody,
              key: const Key('weekly_productivity_report_empty_body'),
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              WeeklyProductivityReportCopy.emptyHelper,
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.totalReactions});

  final int totalReactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('weekly_productivity_report_hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            WeeklyProductivityReportCopy.heroEyebrow,
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            WeeklyProductivityReportCopy.heroTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            WeeklyProductivityReportCopy.heroSubtitle(totalReactions),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionBreakdownCard extends StatelessWidget {
  const _ReactionBreakdownCard({required this.breakdown});

  final Map<String, double> breakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('weekly_productivity_report_breakdown'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            WeeklyProductivityReportCopy.breakdownTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            WeeklyProductivityReportCopy.breakdownHelper,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final reaction in YesterdaysSnapshotReaction.values) ...[
            _ReactionBreakdownRow(
              reaction: reaction,
              share: breakdown[reaction.name] ?? 0,
            ),
            if (reaction != YesterdaysSnapshotReaction.values.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ReactionBreakdownRow extends StatelessWidget {
  const _ReactionBreakdownRow({required this.reaction, required this.share});

  final YesterdaysSnapshotReaction reaction;
  final double share;

  Color get _accent {
    switch (reaction) {
      case YesterdaysSnapshotReaction.progressed:
        return const Color(0xFF3D8B63);
      case YesterdaysSnapshotReaction.stuck:
        return const Color(0xFFC58A1A);
      case YesterdaysSnapshotReaction.pivot:
        return const Color(0xFFC45C5C);
    }
  }

  Color get _track {
    switch (reaction) {
      case YesterdaysSnapshotReaction.progressed:
        return const Color(0xFFEAF6EE);
      case YesterdaysSnapshotReaction.stuck:
        return const Color(0xFFFFF6E8);
      case YesterdaysSnapshotReaction.pivot:
        return const Color(0xFFFDECEC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(share * 100).round()}%';

    return Semantics(
      label: '${reaction.label} $percentLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(reaction.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  reaction.label,
                  key: Key(
                    'weekly_productivity_report_reaction_${reaction.name}',
                  ),
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
              ),
              Text(
                percentLabel,
                key: Key('weekly_productivity_report_percent_${reaction.name}'),
                style: ArchiveMobileTypography.cardLabel(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: _track,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnchorSection extends StatelessWidget {
  const _AnchorSection({
    super.key,
    required this.title,
    required this.helper,
    required this.emptyCopy,
    required this.anchors,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String helper;
  final String emptyCopy;
  final List<String> anchors;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textPrimary.withValues(alpha: 0.85)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  key: Key('weekly_productivity_report_section_$title'),
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            helper,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (anchors.isEmpty)
            Text(
              emptyCopy,
              style: ArchiveMobileTypography.explanationBody(context),
            )
          else
            for (var i = 0; i < anchors.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == anchors.length - 1 ? 0 : AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: ArchiveMobileTypography.explanationBody(context),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        anchors[i],
                        key: Key('weekly_productivity_report_anchor_$i'),
                        style: ArchiveMobileTypography.explanationBody(context),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ExportPortabilitySection extends StatelessWidget {
  const _ExportPortabilitySection({
    required this.exporting,
    required this.onExportMarkdown,
    required this.onExportJson,
  });

  final bool exporting;
  final VoidCallback onExportMarkdown;
  final VoidCallback onExportJson;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('weekly_productivity_report_export_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            WeeklyProductivityReportCopy.exportSectionTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            WeeklyProductivityReportCopy.exportSectionHelper,
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('weekly_productivity_report_export_markdown'),
            onPressed: exporting ? null : onExportMarkdown,
            child: Text(WeeklyProductivityReportCopy.exportMarkdownLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('weekly_productivity_report_export_json'),
            onPressed: exporting ? null : onExportJson,
            child: Text(WeeklyProductivityReportCopy.exportJsonLabel),
          ),
        ],
      ),
    );
  }
}
