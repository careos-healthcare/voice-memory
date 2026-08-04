import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/ui/glassmorphic_container.dart';
import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../apex_benchmark_runner.dart';
import '../apex_profiler_service.dart';

typedef ApexOwnerAuthorizer = Future<bool> Function();

final class ApexProfilerSheet extends StatefulWidget {
  const ApexProfilerSheet({
    super.key,
    required this.service,
    required this.authorizeOwner,
  });

  final ApexProfilerService service;
  final ApexOwnerAuthorizer authorizeOwner;

  static Future<void> show({
    required BuildContext context,
    required ApexProfilerService service,
    required ApexOwnerAuthorizer authorizeOwner,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: '/apex-profiler',
    builder: (_) =>
        ApexProfilerSheet(service: service, authorizeOwner: authorizeOwner),
  );

  @override
  State<ApexProfilerSheet> createState() => _ApexProfilerSheetState();
}

class _ApexProfilerSheetState extends State<ApexProfilerSheet> {
  ApexBenchmarkResult? _result;
  bool _running = false;
  double _progress = 0;
  String? _leakStatus;
  StreamSubscription<double>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _progressSubscription = widget.service.benchmarkRunner.progress.listen((
      value,
    ) {
      if (mounted) setState(() => _progress = value);
    });
  }

  Future<void> _run() async {
    if (!await widget.authorizeOwner() || !mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Run isolated stress benchmark?'),
            content: const Text(
              'This foreground-only test can increase heat and battery use. '
              'It uses temporary stores and never mutates your real archive.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('apex-confirm-run'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Run benchmark'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _running = true;
      _progress = 0;
      _result = null;
    });
    final result = await widget.service.benchmarkRunner.run(
      ownerAuthorized: true,
    );
    if (mounted) {
      setState(() {
        _result = result;
        _running = false;
      });
    }
  }

  Future<void> _exportReport() async {
    final report = _result?.report;
    if (report == null || !await widget.authorizeOwner() || !mounted) return;
    await Share.shareXFiles([
      XFile(report.path, mimeType: 'application/octet-stream'),
    ], subject: 'Encrypted Apex performance audit');
  }

  void _assertLeaks() {
    try {
      widget.service.ffiMonitor.assertNoLeaks();
      setState(() => _leakStatus = 'No active app-owned resource leaks.');
    } on StateError catch (error) {
      setState(() => _leakStatus = error.message);
    }
  }

  @override
  void dispose() {
    unawaited(_progressSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: GlassmorphicContainer(
      renderQuality: GlassRenderQuality.reduced,
      radius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: StreamBuilder<ApexTelemetrySnapshot>(
        stream: widget.service.telemetry,
        initialData: widget.service.current,
        builder: (context, snapshot) {
          final telemetry = snapshot.data ?? widget.service.current;
          return Material(
            color: Colors.transparent,
            child: ListView(
              key: const Key('apex-profiler-sheet'),
              padding: const EdgeInsets.all(8),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Apex Profiler',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Local performance and app-owned native resource safety',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Gauge(
                      key: const Key('apex-gauge-fps'),
                      label: 'FPS',
                      value: telemetry.frames.fps.toStringAsFixed(1),
                      detail:
                          '${telemetry.frames.qualityTier.name} · '
                          'p95 ${telemetry.frames.p95FrameMs.toStringAsFixed(1)}ms',
                    ),
                    _Gauge(
                      key: const Key('apex-gauge-ram'),
                      label: 'Process RAM',
                      value: _bytes(telemetry.ffi.processRssBytes),
                      detail: 'sampled RSS',
                    ),
                    _Gauge(
                      key: const Key('apex-gauge-ffi'),
                      label: 'Active FFI',
                      value: '${telemetry.ffi.activeCount}',
                      detail: 'app-owned',
                    ),
                    _Gauge(
                      key: const Key('apex-gauge-native-guard'),
                      label: 'Native guard',
                      value: telemetry.nativeGuard.available
                          ? '${telemetry.nativeGuard.activeCount}'
                          : 'Unavailable',
                      detail: telemetry.nativeGuard.available
                          ? 'exact ABI-v1 counter'
                          : 'capability-gated',
                    ),
                    _Gauge(
                      key: const Key('apex-gauge-vector'),
                      label: 'Vector KNN',
                      value: telemetry.frames.vectorLatencyMs == null
                          ? 'Unavailable'
                          : '${telemetry.frames.vectorLatencyMs!.toStringAsFixed(1)} ms',
                      detail: 'sampled local latency',
                    ),
                    _Gauge(
                      label: 'SQLite cache',
                      value: telemetry.sqliteCacheBytes == null
                          ? 'Unavailable'
                          : _bytes(telemetry.sqliteCacheBytes!),
                      detail: 'capability-gated',
                    ),
                    _Gauge(
                      label: 'CPU / GPU',
                      value:
                          telemetry.cpuPercent == null &&
                              telemetry.gpuPercent == null
                          ? 'Unavailable'
                          : '${telemetry.cpuPercent ?? '—'} / '
                                '${telemetry.gpuPercent ?? '—'}',
                      detail: 'no inferred metrics',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Quality policy: ${telemetry.frames.reason}',
                  key: const Key('apex-quality-reason'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    telemetry.ffi.pressureHigh
                        ? Icons.warning_amber
                        : Icons.verified_outlined,
                  ),
                  title: Text(
                    telemetry.ffi.pressureHigh
                        ? 'Resource pressure elevated'
                        : 'Native resource ledger healthy',
                  ),
                  subtitle: Text(
                    '${telemetry.ffi.finalizerLeakCount} finalizer backstops, '
                    '${telemetry.ffi.duplicateReleaseCount} invalid releases',
                  ),
                ),
                const Divider(),
                OutlinedButton.icon(
                  key: const Key('apex-assert-leaks'),
                  onPressed: _assertLeaks,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Assert app-owned resource balance'),
                ),
                if (_leakStatus != null)
                  Text(_leakStatus!, key: const Key('apex-leak-status')),
                const Divider(),
                const Text(
                  'Isolated benchmark suite',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_running) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('apex-cancel-benchmark'),
                    onPressed: widget.service.benchmarkRunner.cancel,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Cancel benchmark'),
                  ),
                ] else
                  FilledButton.icon(
                    key: const Key('apex-run-benchmark'),
                    onPressed: _run,
                    icon: const Icon(Icons.speed),
                    label: const Text('Run owner-authorized benchmark'),
                  ),
                if (_result case final result?) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Status: ${result.status.name}',
                    key: const Key('apex-benchmark-status'),
                  ),
                  if (result.message != null) Text(result.message!),
                  if (result.skippedScenarios.isNotEmpty)
                    Text(
                      result.skippedScenarios.entries
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join('\n'),
                      key: const Key('apex-skipped-scenarios'),
                    ),
                  if (result.report != null)
                    OutlinedButton.icon(
                      key: const Key('apex-export-report'),
                      onPressed: _exportReport,
                      icon: const Icon(Icons.ios_share),
                      label: Text(
                        'Export encrypted '
                        '${result.report!.path.split('/').last}',
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Third-party allocator memory is represented only by '
                  'process RSS samples. Apex does not claim that unsupported '
                  'CPU, GPU, or cache metrics are exact.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

final class _Gauge extends StatelessWidget {
  const _Gauge({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

String _bytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
