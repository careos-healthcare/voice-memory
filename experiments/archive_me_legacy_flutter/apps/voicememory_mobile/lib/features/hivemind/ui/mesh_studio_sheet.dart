import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../../../services/p2p_mesh/offload_policy_engine.dart';
import '../hivemind_models.dart';

typedef MeshGovernanceChanged =
    Future<void> Function(HivemindGovernance governance);

final class MeshStudioSheet extends StatefulWidget {
  const MeshStudioSheet({
    super.key,
    required this.peers,
    required this.capabilities,
    required this.governance,
    required this.onGovernanceChanged,
    required this.onReconcile,
    this.onManageNearby,
    this.policyEngine,
  });

  final List<HivemindPeerState> peers;
  final List<HivemindTransportCapability> capabilities;
  final HivemindGovernance governance;
  final MeshGovernanceChanged onGovernanceChanged;
  final Future<void> Function() onReconcile;
  final VoidCallback? onManageNearby;
  final OffloadPolicyEngine? policyEngine;

  static Future<void> show({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'sovereign-mesh-studio',
    builder: builder,
  );

  @override
  State<MeshStudioSheet> createState() => _MeshStudioSheetState();
}

class _MeshStudioSheetState extends State<MeshStudioSheet>
    with SingleTickerProviderStateMixin {
  late HivemindGovernance _governance = widget.governance;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  bool _saving = false;
  bool _reconciling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_pulse.repeat());
    }
  }

  @override
  void didUpdateWidget(MeshStudioSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governance != widget.governance && !_saving) {
      _governance = widget.governance;
    }
  }

  Future<void> _update(HivemindGovernance value) async {
    setState(() {
      _governance = value;
      _saving = true;
    });
    try {
      await widget.onGovernanceChanged(value);
    } on Object {
      if (mounted) setState(() => _governance = widget.governance);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reconcile() async {
    if (_reconciling) return;
    setState(() => _reconciling = true);
    try {
      await widget.onReconcile();
    } finally {
      if (mounted) setState(() => _reconciling = false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = widget.peers.where((peer) => peer.connected).toList();
    return SafeArea(
      child: ListView(
        key: const Key('mesh-studio-sheet'),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sovereign Mesh Studio',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Text(
            'Air-gapped CRDT sync and local Anchor compute · zero cloud',
          ),
          const SizedBox(height: 10),
          StreamBuilder<OffloadPolicySnapshot>(
            stream:
                (widget.policyEngine ?? OffloadPolicyEngine.instance).snapshots,
            initialData:
                (widget.policyEngine ?? OffloadPolicyEngine.instance).current,
            builder: (context, snapshot) {
              final diagnostics =
                  snapshot.data ?? OffloadPolicySnapshot.initial();
              return Wrap(
                key: const Key('mesh-offload-diagnostics'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    key: const Key('mesh-thermal-chip'),
                    avatar: const Icon(Icons.device_thermostat, size: 18),
                    label: Text('Thermal ${diagnostics.thermal.name}'),
                  ),
                  Chip(
                    key: const Key('mesh-battery-chip'),
                    avatar: const Icon(Icons.battery_saver, size: 18),
                    label: Text('Battery ${_batteryLabel(diagnostics)}'),
                  ),
                  Chip(
                    key: const Key('mesh-anchor-ping-chip'),
                    avatar: const Icon(Icons.network_ping, size: 18),
                    label: Text('Anchor ${_pingLabel(diagnostics)}'),
                  ),
                  Chip(
                    key: const Key('mesh-policy-chip'),
                    avatar: const Icon(Icons.route_outlined, size: 18),
                    label: Text(diagnostics.policy.wireName),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          GlassmorphicContainer(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              key: const Key('mesh-network-topology'),
              height: 250,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _MeshTopologyPainter(
                    peers: connected,
                    pulse: _pulse.value,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GlassmorphicContainer(
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const Key('mesh-auto-sync-toggle'),
                    title: const Text('Automatic local reconciliation'),
                    subtitle: const Text(
                      'Exchange encrypted deltas when trusted peers appear',
                    ),
                    value: _governance.automaticSyncEnabled,
                    onChanged: _saving
                        ? null
                        : (value) => unawaited(
                            _update(
                              _governance.copyWith(automaticSyncEnabled: value),
                            ),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    key: const Key('mesh-offload-toggle'),
                    title: const Text('Automatic Anchor offload'),
                    subtitle: const Text(
                      'Delegate embeddings, Council, and Muse batches',
                    ),
                    value: _governance.computeOffloadEnabled,
                    onChanged: _saving
                        ? null
                        : (value) => unawaited(
                            _update(
                              _governance.copyWith(
                                computeOffloadEnabled: value,
                              ),
                            ),
                          ),
                  ),
                  SwitchListTile.adaptive(
                    key: const Key('mesh-share-compute-toggle'),
                    title: const Text('Act as an Anchor Node'),
                    subtitle: const Text(
                      'Accept signed jobs from verified Sanctuary identities',
                    ),
                    value: _governance.acceptRemoteCompute,
                    onChanged: _saving
                        ? null
                        : (value) => unawaited(
                            _update(
                              _governance.copyWith(acceptRemoteCompute: value),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('mesh-reconcile-now'),
            onPressed: connected.isEmpty || _reconciling
                ? null
                : () => unawaited(_reconcile()),
            icon: _reconciling
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('Reconcile trusted peers now'),
          ),
          if (widget.onManageNearby != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('mesh-manage-nearby'),
              onPressed: widget.onManageNearby,
              icon: const Icon(Icons.device_hub_outlined),
              label: const Text('Pair and manage nearby devices'),
            ),
          ],
          const SizedBox(height: 18),
          Text('Active local nodes', style: theme.textTheme.titleMedium),
          if (connected.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No verified local peers are connected.'),
            )
          else
            ...connected.map(
              (peer) => Card(
                key: Key('mesh-peer-${peer.peerId}'),
                child: ListTile(
                  leading: Icon(_deviceIcon(peer.deviceKind)),
                  title: Text(peer.displayName),
                  subtitle: Text(
                    '${peer.transport.name.toUpperCase()} · '
                    '${peer.latency.inMilliseconds} ms · '
                    '${_throughput(peer.throughputBytesPerSecond)}',
                  ),
                  trailing: Icon(
                    peer.offloadAccepted
                        ? Icons.memory_outlined
                        : Icons.shield_outlined,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('Local transports', style: theme.textTheme.titleMedium),
          ...widget.capabilities.map(
            (capability) => ListTile(
              dense: true,
              leading: Icon(
                capability.available
                    ? Icons.lock_outline
                    : Icons.portable_wifi_off_outlined,
              ),
              title: Text(capability.kind.name),
              subtitle: Text(
                capability.available ? capability.backend : capability.reason,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _MeshTopologyPainter extends CustomPainter {
  const _MeshTopologyPainter({
    required this.peers,
    required this.pulse,
    required this.color,
  });

  final List<HivemindPeerState> peers;
  final double pulse;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .36;
    final line = Paint()
      ..color = color.withValues(alpha: .34)
      ..strokeWidth = 1.5;
    final node = Paint()..color = color;
    canvas.drawCircle(
      center,
      14 + (math.sin(pulse * math.pi * 2).abs() * 3),
      node,
    );
    for (var index = 0; index < peers.length; index++) {
      final angle =
          (math.pi * 2 * index / math.max(peers.length, 1)) - (math.pi / 2);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final latency = peers[index].latency.inMilliseconds.clamp(0, 500);
      line.strokeWidth = 3 - ((latency / 500) * 2);
      canvas
        ..drawLine(center, point, line)
        ..drawCircle(point, 9, node);
    }
  }

  @override
  bool shouldRepaint(_MeshTopologyPainter oldDelegate) =>
      oldDelegate.peers != peers ||
      oldDelegate.pulse != pulse ||
      oldDelegate.color != color;
}

IconData _deviceIcon(HivemindDeviceKind kind) => switch (kind) {
  HivemindDeviceKind.phone => Icons.phone_iphone,
  HivemindDeviceKind.tablet => Icons.tablet_mac,
  HivemindDeviceKind.desktop => Icons.desktop_mac_outlined,
  HivemindDeviceKind.unknown => Icons.devices_other,
};

String _throughput(double value) {
  if (value >= 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB/s';
  return '${value.toStringAsFixed(0)} B/s';
}

String _batteryLabel(OffloadPolicySnapshot snapshot) {
  final percent = snapshot.batteryPercent < 0
      ? 'unknown'
      : '${snapshot.batteryPercent}%';
  return '$percent · ${snapshot.batteryTrajectory.name}';
}

String _pingLabel(OffloadPolicySnapshot snapshot) {
  final ping = snapshot.anchorPing;
  if (ping == null) return snapshot.anchorPingState.name;
  return '${ping.inMilliseconds} ms';
}
