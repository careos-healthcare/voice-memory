import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/revenue_readiness/revenue_readiness_dashboard_v2_copy.dart';
import '../../features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import '../../features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import '../../features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import '../../features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta-only unified revenue readiness dashboard — metadata counts only.
class RevenueReadinessDashboardV2Card extends StatefulWidget {
  const RevenueReadinessDashboardV2Card({
    super.key,
    this.source = 'testing_archiveme',
    this.compact = false,
    this.dashboardOverride,
  });

  final String source;
  final bool compact;
  final RevenueReadinessDashboardV2Dashboard? dashboardOverride;

  @override
  State<RevenueReadinessDashboardV2Card> createState() =>
      _RevenueReadinessDashboardV2CardState();
}

class _RevenueReadinessDashboardV2CardState
    extends State<RevenueReadinessDashboardV2Card> {
  RevenueReadinessDashboardV2Dashboard? _dashboard;

  @override
  void initState() {
    super.initState();
    if (widget.dashboardOverride != null) {
      _dashboard = widget.dashboardOverride;
      return;
    }
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final dashboard = await RevenueReadinessDashboardV2Engine.build();
    if (!mounted) return;
    setState(() => _dashboard = dashboard);
  }

  @override
  Widget build(BuildContext context) {
    if (!RevenueReadinessDashboardV2Engine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('revenue_readiness_dashboard_v2_hidden'),
      );
    }

    final dashboard = _dashboard;
    if (dashboard == null) {
      return const SizedBox.shrink(
        key: Key('revenue_readiness_dashboard_v2_loading'),
      );
    }

    return Container(
      key: const Key('revenue_readiness_dashboard_v2_card'),
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dashboard.title,
            key: const Key('revenue_readiness_dashboard_v2_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            dashboard.subtitle,
            key: const Key('revenue_readiness_dashboard_v2_subtitle'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _LiftFocusBlock(liftFocus: dashboard.liftFocus),
          const SizedBox(height: 12),
          for (final section in dashboard.sections) ...[
            _SectionBlock(section: section),
            const SizedBox(height: 10),
          ],
          _DiagnosisBlock(diagnoses: dashboard.diagnoses),
          const SizedBox(height: 4),
          Text(
            RevenueReadinessDashboardV2Copy.localCountsNote,
            key: const Key('revenue_readiness_dashboard_v2_note'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiftFocusBlock extends StatelessWidget {
  const _LiftFocusBlock({required this.liftFocus});

  final RevenueLiftExperimentV2LiftFocus liftFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('revenue_readiness_dashboard_v2_lift_focus'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RevenueLiftExperimentV2Copy.liftFocusSectionTitle,
            key: const Key('revenue_readiness_dashboard_v2_lift_focus_title'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            liftFocus.label,
            key: Key(
              'revenue_readiness_dashboard_v2_lift_focus_${liftFocus.focus.analyticsValue}',
            ),
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final RevenueReadinessDashboardV2Section section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section.title,
          key: Key('revenue_readiness_dashboard_v2_section_${section.id.name}'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        for (final row in section.rows) ...[
          _MetricRowTile(row: row),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _DiagnosisBlock extends StatelessWidget {
  const _DiagnosisBlock({required this.diagnoses});

  final List<RevenueReadinessDashboardV2Diagnosis> diagnoses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          RevenueReadinessDashboardV2Copy.sectionDiagnosis,
          key: const Key('revenue_readiness_dashboard_v2_section_diagnosis'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (diagnoses.isEmpty)
          Text(
            RevenueReadinessDashboardV2Copy.noDiagnosesLine,
            key: const Key('revenue_readiness_dashboard_v2_no_diagnoses'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          )
        else
          for (final diagnosis in diagnoses) ...[
            _DiagnosisTile(diagnosis: diagnosis),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _MetricRowTile extends StatelessWidget {
  const _MetricRowTile({required this.row});

  final RevenueReadinessDashboardV2MetricRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('revenue_readiness_dashboard_v2_metric_${row.id.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.label,
                  key: Key('revenue_readiness_dashboard_v2_label_${row.id.name}'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                row.status.label,
                key: Key('revenue_readiness_dashboard_v2_status_${row.id.name}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(row.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            row.valueLabel,
            key: Key('revenue_readiness_dashboard_v2_value_${row.id.name}'),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          if (row.nextActionLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              '${RevenueReadinessDashboardV2Copy.nextActionPrefix}: '
              '${row.nextActionLabel}',
              key: Key('revenue_readiness_dashboard_v2_action_${row.id.name}'),
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(RevenueReadinessDashboardV2Status status) {
    return switch (status) {
      RevenueReadinessDashboardV2Status.healthy => AppColors.success,
      RevenueReadinessDashboardV2Status.watch => AppColors.warning,
      RevenueReadinessDashboardV2Status.failing => AppColors.error,
      RevenueReadinessDashboardV2Status.noData => AppTheme.muted,
    };
  }
}

class _DiagnosisTile extends StatelessWidget {
  const _DiagnosisTile({required this.diagnosis});

  final RevenueReadinessDashboardV2Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('revenue_readiness_dashboard_v2_diagnosis_${diagnosis.id.name}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diagnosis.title,
            key: Key(
              'revenue_readiness_dashboard_v2_diagnosis_title_${diagnosis.id.name}',
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (diagnosis.metricValueLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              diagnosis.metricValueLabel!,
              key: Key(
                'revenue_readiness_dashboard_v2_diagnosis_value_${diagnosis.id.name}',
              ),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${RevenueReadinessDashboardV2Copy.nextActionPrefix}: '
            '${diagnosis.nextActionLabel}',
            key: Key(
              'revenue_readiness_dashboard_v2_diagnosis_action_${diagnosis.id.name}',
            ),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
