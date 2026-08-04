import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/glassmorphic_container.dart';
import '../sanctuary_models.dart';

typedef SanctuaryReportLoader = Future<SanctuaryHealthReport> Function();
typedef SanctuaryToggle = Future<void> Function(bool enabled);
typedef SanctuaryWipe = Future<bool> Function();
typedef SanctuaryWipeAuthorizer = Future<bool> Function();

final class SanctuaryCoreDashboard extends StatefulWidget {
  const SanctuaryCoreDashboard({
    super.key,
    required this.loadReport,
    required this.initialGovernance,
    required this.onMuseChanged,
    required this.onBrowserBridgeChanged,
    required this.onPeerDiscoveryChanged,
    required this.authorizeWipe,
    required this.onEmergencyWipe,
    required this.onOpenKeyring,
    required this.onClose,
    this.meshPeerCount = 0,
    this.syncHealthy = true,
    this.onOpenHivemind,
    this.onOpenApexProfiler,
    this.onOpenCatalyst,
    this.onOpenSandbox,
    this.onOpenCodex,
    this.onOpenImportStudio,
  });

  final SanctuaryReportLoader loadReport;
  final SanctuaryGovernanceState initialGovernance;
  final SanctuaryToggle onMuseChanged;
  final SanctuaryToggle onBrowserBridgeChanged;
  final SanctuaryToggle onPeerDiscoveryChanged;
  final SanctuaryWipeAuthorizer authorizeWipe;
  final SanctuaryWipe onEmergencyWipe;
  final VoidCallback onOpenKeyring;
  final VoidCallback onClose;
  final int meshPeerCount;
  final bool syncHealthy;
  final VoidCallback? onOpenHivemind;
  final VoidCallback? onOpenApexProfiler;
  final VoidCallback? onOpenCatalyst;
  final VoidCallback? onOpenSandbox;
  final VoidCallback? onOpenCodex;
  final VoidCallback? onOpenImportStudio;

  @override
  State<SanctuaryCoreDashboard> createState() => _SanctuaryCoreDashboardState();
}

class _SanctuaryCoreDashboardState extends State<SanctuaryCoreDashboard> {
  late Future<SanctuaryHealthReport> _report = widget.loadReport();
  late SanctuaryGovernanceState _governance = widget.initialGovernance;
  bool _busy = false;
  String? _status;

  Future<void> _toggle(
    SanctuaryGovernanceState next,
    SanctuaryToggle callback,
    bool value,
  ) async {
    setState(() {
      _governance = next;
      _busy = true;
      _status = null;
    });
    try {
      await callback(value);
    } on Object {
      if (mounted) {
        setState(() {
          _governance = widget.initialGovernance;
          _status = 'That governance change could not be applied.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wipe() async {
    if (!await widget.authorizeWipe() || !mounted) {
      setState(
        () => _status = 'Device-owner authentication was not completed.',
      );
      return;
    }
    final controller = TextEditingController();
    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Nuclear Wipe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This permanently removes the local archive, derived AI '
                  'data, local models, and agent state. Type WIPE MY SANCTUARY.',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('sanctuary-wipe-confirm-field'),
                  controller: controller,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('sanctuary-wipe-confirm'),
                onPressed: () => Navigator.pop(
                  context,
                  controller.text.trim() == 'WIPE MY SANCTUARY',
                ),
                child: const Text('Permanently wipe'),
              ),
            ],
          ),
        ) ??
        false;
    controller.dispose();
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final wiped = await widget.onEmergencyWipe();
      if (mounted) {
        setState(
          () => _status = wiped
              ? 'Local Sanctuary data was wiped.'
              : 'Emergency wipe was cancelled.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GlassmorphicContainer(
          key: const Key('sanctuary-core-dashboard'),
          radius: BorderRadius.circular(34),
          blurSigma: 24,
          padding: const EdgeInsets.all(20),
          child: Material(
            color: Colors.transparent,
            child: ListView(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_moon_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sanctuary Core',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Sovereign local governance · zero-knowledge command center',
                ),
                const SizedBox(height: 20),
                FutureBuilder<SanctuaryHealthReport>(
                  future: _report,
                  builder: (context, snapshot) {
                    final report = snapshot.data;
                    return _SystemStatus(
                      report: report,
                      meshPeerCount: widget.meshPeerCount,
                      syncHealthy: widget.syncHealthy,
                      onRefresh: () =>
                          setState(() => _report = widget.loadReport()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Agent swarm governance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  key: const Key('sanctuary-muse-toggle'),
                  title: const Text('Autonomous Muse'),
                  subtitle: const Text('Idle local bridge-discovery sweeps'),
                  value: _governance.museEnabled,
                  onChanged: _busy
                      ? null
                      : (value) => unawaited(
                          _toggle(
                            _governance.copyWith(museEnabled: value),
                            widget.onMuseChanged,
                            value,
                          ),
                        ),
                ),
                SwitchListTile(
                  key: const Key('sanctuary-browser-toggle'),
                  title: const Text('Web Clipper bridge'),
                  subtitle: const Text('Localhost-only encrypted companion'),
                  value: _governance.browserBridgeEnabled,
                  onChanged: _busy
                      ? null
                      : (value) => unawaited(
                          _toggle(
                            _governance.copyWith(browserBridgeEnabled: value),
                            widget.onBrowserBridgeChanged,
                            value,
                          ),
                        ),
                ),
                SwitchListTile(
                  key: const Key('sanctuary-mesh-toggle'),
                  title: const Text('Local peer discovery'),
                  subtitle: const Text('Local-network encrypted mesh presence'),
                  value: _governance.peerDiscoveryEnabled,
                  onChanged: _busy
                      ? null
                      : (value) => unawaited(
                          _toggle(
                            _governance.copyWith(peerDiscoveryEnabled: value),
                            widget.onPeerDiscoveryChanged,
                            value,
                          ),
                        ),
                ),
                if (widget.onOpenHivemind != null)
                  OutlinedButton.icon(
                    key: const Key('sanctuary-open-hivemind'),
                    onPressed: widget.onOpenHivemind,
                    icon: const Icon(Icons.hub_outlined),
                    label: const Text('Open Hivemind control center'),
                  ),
                if (widget.onOpenApexProfiler != null)
                  OutlinedButton.icon(
                    key: const Key('sanctuary-open-apex-profiler'),
                    onPressed: widget.onOpenApexProfiler,
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Open Apex Profiler'),
                  ),
                if (widget.onOpenCatalyst != null)
                  OutlinedButton.icon(
                    key: const Key('sanctuary-open-catalyst'),
                    onPressed: widget.onOpenCatalyst,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Open Catalyst Studio'),
                  ),
                if (widget.onOpenSandbox != null)
                  OutlinedButton.icon(
                    key: const Key('sanctuary-open-sandbox'),
                    onPressed: widget.onOpenSandbox,
                    icon: const Icon(Icons.security_outlined),
                    label: const Text('Open Wasm Sandbox'),
                  ),
                if (widget.onOpenCodex != null)
                  OutlinedButton.icon(
                    key: const Key('sanctuary-open-codex'),
                    onPressed: widget.onOpenCodex,
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('Open Sovereign Codex Press'),
                  ),
                if (widget.onOpenImportStudio != null)
                  OutlinedButton.icon(
                    key: const Key('sanctuary-open-import-studio'),
                    onPressed: widget.onOpenImportStudio,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    label: const Text('Open Legacy Import Studio'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('sanctuary-open-keyring'),
                  onPressed: widget.onOpenKeyring,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Open sovereign keyring'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('sanctuary-nuclear-wipe'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _busy ? null : _wipe,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Emergency Privacy Wipe'),
                ),
                if (_status case final status?) ...[
                  const SizedBox(height: 10),
                  Text(status, key: const Key('sanctuary-dashboard-status')),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _SystemStatus extends StatelessWidget {
  const _SystemStatus({
    required this.report,
    required this.meshPeerCount,
    required this.syncHealthy,
    required this.onRefresh,
  });

  final SanctuaryHealthReport? report;
  final int meshPeerCount;
  final bool syncHealthy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final fraction = report?.healthFraction ?? 0;
    return GlassmorphicContainer(
      radius: BorderRadius.circular(24),
      blurSigma: 12,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 96,
            child: CustomPaint(
              key: const Key('sanctuary-status-ring'),
              painter: _StatusRingPainter(
                fraction: fraction,
                failed: report?.hasFailures == true,
              ),
              child: Center(child: Text('${(fraction * 100).round()}%')),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report?.hasFailures == true
                      ? 'Attention required'
                      : 'Zero-knowledge systems healthy',
                ),
                Text('$meshPeerCount nearby mesh peers'),
                Text(
                  syncHealthy
                      ? 'Background sync healthy'
                      : 'Sync needs attention',
                ),
                if (report != null) Text(_formatBytes(report!.totalBytes)),
              ],
            ),
          ),
          IconButton(
            key: const Key('sanctuary-refresh-health'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

final class _StatusRingPainter extends CustomPainter {
  const _StatusRingPainter({required this.fraction, required this.failed});

  final double fraction;
  final bool failed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(8),
      0,
      6.283185307179586,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    canvas.drawArc(
      rect.deflate(8),
      -1.5707963267948966,
      6.283185307179586 * fraction.clamp(0, 1),
      false,
      Paint()
        ..color = failed ? const Color(0xFFFF6B6B) : const Color(0xFF5FE1C2)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 9,
    );
  }

  @override
  bool shouldRepaint(covariant _StatusRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.failed != failed;
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB local';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB local';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB local';
}
