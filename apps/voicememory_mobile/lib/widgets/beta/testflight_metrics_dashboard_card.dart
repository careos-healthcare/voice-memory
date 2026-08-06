import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/testflight_metrics/testflight_metrics_analytics.dart';
import '../../features/testflight_metrics/testflight_metrics_copy.dart';
import '../../features/testflight_metrics/testflight_metrics_engine.dart';
import '../../features/testflight_metrics/testflight_metrics_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta-only local metrics dashboard — metadata counts only.
class TestFlightMetricsDashboardCard extends StatefulWidget {
  const TestFlightMetricsDashboardCard({
    super.key,
    this.source = 'settings',
    this.surface = 'settings',
    this.compact = false,
    this.dashboardOverride,
  });

  final String source;
  final String surface;
  final bool compact;
  final TestFlightMetricsDashboard? dashboardOverride;

  @override
  State<TestFlightMetricsDashboardCard> createState() =>
      _TestFlightMetricsDashboardCardState();
}

class _TestFlightMetricsDashboardCardState
    extends State<TestFlightMetricsDashboardCard> {
  TestFlightMetricsDashboard? _dashboard;
  var _trackedSeen = false;

  @override
  void initState() {
    super.initState();
    if (widget.dashboardOverride != null) {
      _dashboard = widget.dashboardOverride;
      return;
    }
    _loadDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dashboard = _dashboard;
    if (dashboard != null &&
        TestFlightMetricsEngine.shouldShow(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
        )) {
      _trackSeenOnce(dashboard.metricCount);
    }
  }

  Future<void> _loadDashboard() async {
    final dashboard = await TestFlightMetricsEngine.build();
    if (!mounted) return;
    setState(() => _dashboard = dashboard);
  }

  void _trackSeenOnce(int metricCount) {
    if (_trackedSeen) return;
    _trackedSeen = true;
    TestFlightMetricsAnalytics.seen(
      source: widget.source,
      surface: widget.surface,
      metricCount: metricCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!TestFlightMetricsEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(
        key: Key('testflight_metrics_dashboard_hidden'),
      );
    }

    final dashboard = _dashboard;
    if (dashboard == null) {
      return const SizedBox.shrink(
        key: Key('testflight_metrics_dashboard_loading'),
      );
    }

    return Container(
      key: const Key('testflight_metrics_dashboard_card'),
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
            key: const Key('testflight_metrics_dashboard_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            dashboard.subtitle,
            key: const Key('testflight_metrics_dashboard_subtitle'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            TestFlightMetricsCopy.coreMetricsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final row in dashboard.coreMetrics) ...[
            _MetricRow(row: row),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          Text(
            TestFlightMetricsCopy.retentionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final row in dashboard.retentionMetrics) ...[
            _MetricRow(row: row),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 4),
          Text(
            TestFlightMetricsCopy.localCountsNote,
            key: const Key('testflight_metrics_dashboard_note'),
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.row});

  final TestFlightMetricRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            row.label,
            key: Key('testflight_metrics_label_${row.id.name}'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(
          row.countLabel,
          key: Key('testflight_metrics_value_${row.id.name}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: row.seen ? AppColors.textPrimary : AppColors.warning,
          ),
        ),
      ],
    );
  }
}
