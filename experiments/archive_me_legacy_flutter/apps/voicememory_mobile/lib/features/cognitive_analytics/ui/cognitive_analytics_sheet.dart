import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../cognitive_metrics_engine.dart';
import '../cognitive_metrics_models.dart';

typedef CognitiveSnapshotLoader =
    Future<CognitiveMetricsSnapshot> Function(CognitiveTimeRange range);

class CognitiveAnalyticsSheet extends StatefulWidget {
  const CognitiveAnalyticsSheet({
    super.key,
    required this.loadSnapshot,
    this.onOpenCognitiveCouncil,
    this.onClose,
  });

  final CognitiveSnapshotLoader loadSnapshot;
  final VoidCallback? onOpenCognitiveCouncil;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required CognitiveMetricsEngine engine,
    VoidCallback? onOpenCognitiveCouncil,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'cognitive-analytics',
    builder: (panelContext) => CognitiveAnalyticsSheet(
      loadSnapshot: engine.calculate,
      onOpenCognitiveCouncil: onOpenCognitiveCouncil,
      onClose: () => Navigator.of(panelContext).pop(),
    ),
  );

  @override
  State<CognitiveAnalyticsSheet> createState() =>
      _CognitiveAnalyticsSheetState();
}

class _CognitiveAnalyticsSheetState extends State<CognitiveAnalyticsSheet> {
  CognitiveTimeRange _range = CognitiveTimeRange.month;
  CognitiveMetricsSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.loadSnapshot(_range);
      if (!mounted || request != _request) return;
      setState(() => _snapshot = snapshot);
    } on Object catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _selectRange(CognitiveTimeRange range) {
    if (_range == range) return;
    setState(() => _range = range);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The Mind Mirror',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'Private · calculated only on this device',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('cognitive-analytics-close'),
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<CognitiveTimeRange>(
                  key: const Key('cognitive-range-selector'),
                  segments: [
                    for (final range in CognitiveTimeRange.values)
                      ButtonSegment(value: range, label: Text(range.label)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (selection) =>
                      _selectRange(selection.single),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(theme)),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _snapshot == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry local calculation'),
        ),
      );
    }
    final snapshot = _snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final points = snapshot.points;
    final latest = snapshot.latest;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('cognitive-analytics-content'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (snapshot.advisory case final advisory?)
            _AdvisoryCard(
              advisory: advisory,
              onOpenCouncil: widget.onOpenCognitiveCouncil,
            ),
          if (snapshot.advisory != null) const SizedBox(height: 14),
          _MetricSummary(latest: latest),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'Emotional Valence',
            subtitle: '7, 30 and 90-day moving averages',
            child: CustomPaint(
              key: const Key('cognitive-valence-chart'),
              painter: _ValenceChartPainter(
                points: points,
                accent: theme.colorScheme.primary,
              ),
              child: const SizedBox(height: 180, width: double.infinity),
            ),
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'Cognitive Load Heatmap',
            subtitle: 'Open loops compared with resolved clusters',
            child: CustomPaint(
              key: const Key('cognitive-load-heatmap'),
              painter: _LoadHeatmapPainter(points: points),
              child: const SizedBox(height: 92, width: double.infinity),
            ),
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'Habit Momentum',
            subtitle: 'Scheduled check-ins and active streaks',
            child: CustomPaint(
              key: const Key('cognitive-habit-chart'),
              painter: _MomentumPainter(
                points: points,
                color: theme.colorScheme.tertiary,
              ),
              child: const SizedBox(height: 120, width: double.infinity),
            ),
          ),
          const SizedBox(height: 14),
          GlassmorphicContainer(
            key: const Key('cognitive-insights-summary'),
            fillColor: theme.colorScheme.surface,
            opacity: .68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Cognitive Insights Summary',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final insight in snapshot.insights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(insight)),
                      ],
                    ),
                  ),
                Text(
                  'Generated locally from aggregate signals. No journal text '
                  'or analytics leaves this device.',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({required this.latest});
  final CognitiveMetricPoint? latest;

  @override
  Widget build(BuildContext context) {
    final point = latest;
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Valence',
            value: point?.movingAverage7 == null
                ? '—'
                : point!.movingAverage7!.toStringAsFixed(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Load',
            value: '${((point?.cognitiveLoad ?? 0) * 100).round()}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Velocity',
            value: '${((point?.semanticVelocity ?? 0) * 100).round()}%',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => GlassmorphicContainer(
    fillColor: Theme.of(context).colorScheme.surface,
    opacity: .64,
    blurSigma: 12,
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => GlassmorphicContainer(
    fillColor: Theme.of(context).colorScheme.surface,
    opacity: .66,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _AdvisoryCard extends StatelessWidget {
  const _AdvisoryCard({required this.advisory, this.onOpenCouncil});
  final BurnoutAdvisory advisory;
  final VoidCallback? onOpenCouncil;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('cognitive-burnout-advisory'),
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.self_improvement_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advisory.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(advisory.message),
          if (onOpenCouncil != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              key: const Key('cognitive-open-council'),
              onPressed: onOpenCouncil,
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Reflect with Cognitive Council'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ValenceChartPainter extends CustomPainter {
  const _ValenceChartPainter({required this.points, required this.accent});
  final List<CognitiveMetricPoint> points;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      grid,
    );
    _line(
      canvas,
      size,
      points.map((point) => point.movingAverage90).toList(),
      accent.withValues(alpha: .25),
      1.5,
    );
    _line(
      canvas,
      size,
      points.map((point) => point.movingAverage30).toList(),
      accent.withValues(alpha: .55),
      2,
    );
    _line(
      canvas,
      size,
      points.map((point) => point.movingAverage7).toList(),
      accent,
      2.8,
    );
  }

  static void _line(
    Canvas canvas,
    Size size,
    List<double?> values,
    Color color,
    double width,
  ) {
    if (values.length < 2) return;
    final path = Path();
    var started = false;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        started = false;
        continue;
      }
      final point = Offset(
        index / max(1, values.length - 1) * size.width,
        (1 - (value + 1) / 2) * size.height,
      );
      if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ValenceChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.accent != accent;
}

class _LoadHeatmapPainter extends CustomPainter {
  const _LoadHeatmapPainter({required this.points});
  final List<CognitiveMetricPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final columns = min(points.length, 52);
    final visible = points.skip(points.length - columns).toList();
    final gap = 3.0;
    final width = (size.width - gap * (columns - 1)) / columns;
    for (var index = 0; index < visible.length; index++) {
      final load = visible[index].cognitiveLoad;
      final color = Color.lerp(
        const Color(0xff3ddc97),
        const Color(0xffff6b6b),
        load,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(index * (width + gap), 0, width, size.height),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: .35 + load * .65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoadHeatmapPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _MomentumPainter extends CustomPainter {
  const _MomentumPainter({required this.points, required this.color});
  final List<CognitiveMetricPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final visible = points.skip(max(0, points.length - 30)).toList();
    final gap = 2.0;
    final width = (size.width - gap * (visible.length - 1)) / visible.length;
    for (var index = 0; index < visible.length; index++) {
      final momentum = visible[index].habitMomentum;
      final height = max(2.0, momentum * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            index * (width + gap),
            size.height - height,
            width,
            height,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: .35 + momentum * .65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
