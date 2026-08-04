import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../hivemind_models.dart';

typedef HivemindGovernanceChanged =
    Future<void> Function(HivemindGovernance governance);

final class HivemindStatusSheet extends StatefulWidget {
  const HivemindStatusSheet({
    super.key,
    required this.peers,
    required this.capabilities,
    required this.governance,
    required this.onGovernanceChanged,
    this.onShowPairingCode,
    this.onScanPairingCode,
    this.onEnterPin,
    this.onManageNearby,
  });

  final List<HivemindPeerState> peers;
  final List<HivemindTransportCapability> capabilities;
  final HivemindGovernance governance;
  final HivemindGovernanceChanged onGovernanceChanged;
  final VoidCallback? onShowPairingCode;
  final VoidCallback? onScanPairingCode;
  final VoidCallback? onEnterPin;
  final VoidCallback? onManageNearby;

  static Future<void> show({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'hivemind-status',
    builder: builder,
  );

  @override
  State<HivemindStatusSheet> createState() => _HivemindStatusSheetState();
}

class _HivemindStatusSheetState extends State<HivemindStatusSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  late HivemindGovernance _governance = widget.governance;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    if (!media.disableAnimations && !media.accessibleNavigation) {
      unawaited(_pulse.repeat());
    } else {
      _pulse.stop();
    }
  }

  @override
  void didUpdateWidget(covariant HivemindStatusSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governance != widget.governance) {
      _governance = widget.governance;
    }
  }

  Future<void> _update(HivemindGovernance governance) async {
    setState(() {
      _governance = governance;
      _busy = true;
    });
    try {
      await widget.onGovernanceChanged(governance);
    } on Object {
      if (mounted) setState(() => _governance = widget.governance);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      key: const Key('hivemind-status-sheet'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.hub_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'The Hivemind',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const Text('Encrypted, direct, zero-cloud memory and compute mesh'),
        const SizedBox(height: 16),
        Semantics(
          label:
              'Hivemind topology with ${widget.peers.where((peer) => peer.connected).length} connected trusted devices',
          child: SizedBox(
            key: const Key('hivemind-topology'),
            height: 240,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                painter: _TopologyPainter(
                  peers: widget.peers,
                  pulse: _pulse.value,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassmorphicContainer(
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('hivemind-discovery-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Local mesh discovery'),
                  subtitle: const Text('NSD/TCP on this local network only'),
                  value: _governance.discoveryEnabled,
                  onChanged: _busy
                      ? null
                      : (value) => unawaited(
                          _update(
                            _governance.copyWith(discoveryEnabled: value),
                          ),
                        ),
                ),
                SwitchListTile(
                  key: const Key('hivemind-offload-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use trusted peer compute'),
                  subtitle: const Text(
                    'Bounded embeddings and structured local-LLM jobs',
                  ),
                  value: _governance.computeOffloadEnabled,
                  onChanged: _busy
                      ? null
                      : (value) => unawaited(
                          _update(
                            _governance.copyWith(computeOffloadEnabled: value),
                          ),
                        ),
                ),
                SwitchListTile(
                  key: const Key('hivemind-share-compute-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Share idle compute'),
                  subtitle: const Text('Only signed jobs from trusted devices'),
                  value: _governance.acceptRemoteCompute,
                  onChanged: _busy
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
        const SizedBox(height: 16),
        Text(
          'Transport contracts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...widget.capabilities.map(
          (capability) => ListTile(
            dense: true,
            leading: Icon(
              capability.available ? Icons.lock_outline : Icons.block_outlined,
            ),
            title: Text(
              '${capability.kind.name} · v${capability.contractVersion}',
            ),
            subtitle: Text(
              capability.available ? capability.backend : capability.reason,
            ),
            trailing: Text(capability.available ? 'Available' : 'Unavailable'),
          ),
        ),
        const SizedBox(height: 12),
        Text('Trusted devices', style: Theme.of(context).textTheme.titleMedium),
        if (widget.peers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No trusted devices are connected.'),
          )
        else
          ...widget.peers.map(
            (peer) => ListTile(
              leading: Icon(_deviceIcon(peer.deviceKind)),
              title: Text(peer.displayName),
              subtitle: Text(
                peer.connected
                    ? '${peer.latency.inMilliseconds} ms · '
                          '${peer.gpuState.name.toUpperCase()}'
                    : 'Disconnected',
              ),
              trailing: Icon(
                peer.connected ? Icons.shield_outlined : Icons.link_off,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('hivemind-show-pairing-code'),
              onPressed: widget.onShowPairingCode,
              icon: const Icon(Icons.qr_code),
              label: const Text('Show QR'),
            ),
            OutlinedButton.icon(
              key: const Key('hivemind-scan-pairing-code'),
              onPressed: widget.onScanPairingCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
            ),
            OutlinedButton.icon(
              key: const Key('hivemind-enter-pin'),
              onPressed: widget.onEnterPin,
              icon: const Icon(Icons.pin_outlined),
              label: const Text('Enter PIN'),
            ),
            OutlinedButton.icon(
              key: const Key('hivemind-manage-nearby'),
              onPressed: widget.onManageNearby,
              icon: const Icon(Icons.device_hub_outlined),
              label: const Text('Manage nearby'),
            ),
          ],
        ),
      ],
    ),
  );
}

IconData _deviceIcon(HivemindDeviceKind kind) => switch (kind) {
  HivemindDeviceKind.phone => Icons.phone_iphone,
  HivemindDeviceKind.tablet => Icons.tablet_mac,
  HivemindDeviceKind.desktop => Icons.laptop_mac,
  HivemindDeviceKind.unknown => Icons.devices_other,
};

final class _TopologyPainter extends CustomPainter {
  const _TopologyPainter({
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
    final connected = peers.where((peer) => peer.connected).toList();
    final line = Paint()
      ..color = color.withValues(alpha: .28)
      ..strokeWidth = 1.5;
    final node = Paint()..color = color;
    canvas.drawCircle(
      center,
      13 + math.sin(pulse * math.pi * 2).abs() * 3,
      node,
    );
    for (var index = 0; index < connected.length; index++) {
      final angle =
          (math.pi * 2 * index / math.max(connected.length, 1)) - math.pi / 2;
      final radius = math.min(size.width, size.height) * .36;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas
        ..drawLine(center, point, line)
        ..drawCircle(point, 8, node);
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) =>
      oldDelegate.peers != peers ||
      oldDelegate.pulse != pulse ||
      oldDelegate.color != color;
}
