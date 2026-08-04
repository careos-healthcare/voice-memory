import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../mesh_models.dart';
import '../vault_share/vault_share_models.dart';
import 'mesh_ui_models.dart';
import 'vault_share_card.dart';

typedef MeshPeerCallback = FutureOr<void> Function(MeshPeer peer);
typedef MeshPairingCallback =
    FutureOr<void> Function(MeshPeer peer, bool confirmed);

class MeshStatusOverlay extends StatelessWidget {
  const MeshStatusOverlay({
    super.key,
    required this.availability,
    required this.peers,
    required this.onPressed,
  });

  final MeshAvailability availability;
  final List<MeshPeerViewState> peers;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trusted = peers.where((item) => item.isTrusted).length;
    final syncing = peers.any(
      (item) => item.syncState == MeshSyncState.syncing,
    );
    final failed = peers.any((item) => item.syncState == MeshSyncState.failed);
    final label = failed
        ? 'Mesh needs attention'
        : syncing
        ? 'Mesh syncing'
        : availability == MeshAvailability.scanning
        ? 'Mesh scanning'
        : availability == MeshAvailability.unavailable
        ? 'Mesh unavailable'
        : '$trusted trusted ${trusted == 1 ? 'peer' : 'peers'} nearby';
    final color = failed
        ? theme.colorScheme.error
        : availability == MeshAvailability.unavailable
        ? theme.colorScheme.outline
        : theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        key: const Key('mesh-status-overlay'),
        color: theme.colorScheme.surface.withValues(alpha: .78),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: .5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failed ? Icons.sync_problem : Icons.hub_outlined,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeshStatusSheet extends StatefulWidget {
  const MeshStatusSheet({
    super.key,
    required this.availability,
    required this.peers,
    required this.onClose,
    this.onPair,
    this.onConfirmPairing,
    this.onRetrySync,
    this.onRevoke,
    this.onBeam,
    this.onImportShare,
    this.sharedBranches = const [],
    this.onOpenBranch,
    this.onScanQr,
    this.onShowQr,
    this.onHaptic,
  });

  final MeshAvailability availability;
  final List<MeshPeerViewState> peers;
  final VoidCallback onClose;
  final MeshPeerCallback? onPair;
  final MeshPairingCallback? onConfirmPairing;
  final MeshPeerCallback? onRetrySync;
  final MeshPeerCallback? onRevoke;
  final MeshPeerCallback? onBeam;
  final VoidCallback? onImportShare;
  final List<SharedVaultBranch> sharedBranches;
  final ValueChanged<SharedVaultBranch>? onOpenBranch;
  final VoidCallback? onScanQr;
  final VoidCallback? onShowQr;
  final MeshHapticCallback? onHaptic;

  @override
  State<MeshStatusSheet> createState() => _MeshStatusSheetState();
}

class _MeshStatusSheetState extends State<MeshStatusSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final shouldAnimate =
        !media.disableAnimations &&
        !media.accessibleNavigation &&
        widget.availability != MeshAvailability.unavailable;
    if (_animate == shouldAnimate) return;
    _animate = shouldAnimate;
    if (_animate) {
      unawaited(_pulse.repeat());
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant MeshStatusSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availability != widget.availability) {
      final media = MediaQuery.of(context);
      final shouldAnimate =
          !media.disableAnimations &&
          !media.accessibleNavigation &&
          widget.availability != MeshAvailability.unavailable;
      if (shouldAnimate != _animate) {
        _animate = shouldAnimate;
        if (_animate) {
          unawaited(_pulse.repeat());
        } else {
          _pulse
            ..stop()
            ..value = 0;
        }
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _haptic(MeshHapticEvent event) => widget.onHaptic?.call(event);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      key: const Key('mesh-status-sheet'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: .88),
          child: SafeArea(
            top: false,
            child: CustomScrollView(
              key: const Key('mesh-status-scroll-view'),
              slivers: [
                SliverToBoxAdapter(child: _header(theme)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: _MeshRadar(
                      peers: widget.peers,
                      pulse: _pulse,
                      animate: _animate,
                    ),
                  ),
                ),
                if (widget.sharedBranches.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    sliver: SliverList.builder(
                      itemCount: widget.sharedBranches.length,
                      itemBuilder: (context, index) =>
                          SharedVaultBranchAttributionCard(
                            branch: widget.sharedBranches[index],
                            onOpen: widget.onOpenBranch,
                          ),
                    ),
                  ),
                if (widget.peers.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No nearby peers yet. Keep this sheet open while scanning.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                    sliver: SliverList.builder(
                      itemCount: widget.peers.length,
                      itemBuilder: (context, index) => _PeerCard(
                        state: widget.peers[index],
                        onPair: widget.onPair,
                        onConfirmPairing: widget.onConfirmPairing,
                        onRetrySync: widget.onRetrySync,
                        onRevoke: widget.onRevoke,
                        onBeam: widget.onBeam,
                        onHaptic: _haptic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
    child: Row(
      children: [
        Icon(Icons.radar, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nearby mesh', style: theme.textTheme.titleLarge),
              Text(
                _availabilityLabel(widget.availability),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (widget.onImportShare != null)
          IconButton(
            key: const Key('mesh-import-share'),
            tooltip: 'Import encrypted vault share',
            onPressed: widget.onImportShare,
            icon: const Icon(Icons.file_download_outlined),
          ),
        if (widget.onShowQr != null)
          IconButton(
            key: const Key('mesh-show-pairing-qr'),
            tooltip: 'Show pairing QR code',
            onPressed: widget.onShowQr,
            icon: const Icon(Icons.qr_code),
          ),
        if (widget.onScanQr != null)
          IconButton(
            key: const Key('mesh-scan-pairing-qr'),
            tooltip: 'Scan pairing QR code',
            onPressed: widget.onScanQr,
            icon: const Icon(Icons.qr_code_scanner),
          ),
        IconButton(
          key: const Key('mesh-status-close'),
          tooltip: 'Close nearby mesh',
          onPressed: widget.onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _MeshRadar extends StatelessWidget {
  const _MeshRadar({
    required this.peers,
    required this.pulse,
    required this.animate,
  });

  final List<MeshPeerViewState> peers;
  final Animation<double> pulse;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label:
          'Radar showing ${peers.length} nearby ${peers.length == 1 ? 'peer' : 'peers'}',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          key: const Key('mesh-radar'),
          height: 180,
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, _) => CustomPaint(
              painter: _RadarPainter(
                peers: peers,
                phase: animate ? pulse.value : 0,
                primary: theme.colorScheme.primary,
                surface: theme.colorScheme.surface,
                trusted: theme.colorScheme.tertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.peers,
    required this.phase,
    required this.primary,
    required this.surface,
    required this.trusted,
  });

  final List<MeshPeerViewState> peers;
  final double phase;
  final Color primary;
  final Color surface;
  final Color trusted;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .43;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 1; index <= 3; index++) {
      ring.color = primary.withValues(alpha: .12 + index * .03);
      canvas.drawCircle(center, radius * index / 3, ring);
    }
    final sweep = Paint()
      ..color = primary.withValues(alpha: .12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * phase, sweep);
    canvas.drawCircle(
      center,
      8,
      Paint()..color = primary.withValues(alpha: .9),
    );
    for (var index = 0; index < peers.length; index++) {
      final peer = peers[index];
      final angle = (index * 2.399) - math.pi / 2;
      final distance = radius * (.38 + (index % 3) * .25);
      final point =
          center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      final color = peer.isTrusted ? trusted : primary;
      final glow = 14 + (math.sin((phase + index / 5) * math.pi * 2) + 1) * 4;
      canvas.drawCircle(
        point,
        glow,
        Paint()..color = color.withValues(alpha: .12),
      );
      canvas.drawCircle(point, 7, Paint()..color = color);
      canvas.drawCircle(
        point,
        4,
        Paint()..color = surface.withValues(alpha: .9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.peers != peers ||
      oldDelegate.primary != primary ||
      oldDelegate.trusted != trusted;
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({
    required this.state,
    required this.onPair,
    required this.onConfirmPairing,
    required this.onRetrySync,
    required this.onRevoke,
    required this.onBeam,
    required this.onHaptic,
  });

  final MeshPeerViewState state;
  final MeshPeerCallback? onPair;
  final MeshPairingCallback? onConfirmPairing;
  final MeshPeerCallback? onRetrySync;
  final MeshPeerCallback? onRevoke;
  final MeshPeerCallback? onBeam;
  final ValueChanged<MeshHapticEvent> onHaptic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peer = state.peer;
    return Semantics(
      container: true,
      label:
          '${peer.name}, ${state.isTrusted ? 'trusted' : 'not trusted'}, '
          '${_syncLabel(state)}',
      child: Card(
        key: Key('mesh-peer-${peer.id}'),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color:
                (state.isTrusted
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.outlineVariant)
                    .withValues(alpha: .55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(peer.name.characters.first.toUpperCase()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(peer.name, style: theme.textTheme.titleMedium),
                        Text(
                          state.isTrusted ? 'Trusted peer' : 'Nearby device',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (state.isTrusted)
                    const Icon(
                      Icons.verified_user_outlined,
                      semanticLabel: 'Trusted',
                    ),
                ],
              ),
              if (state.pairingState ==
                  MeshPairingState.awaitingConfirmation) ...[
                const SizedBox(height: 14),
                Text('Confirm this code on both devices'),
                const SizedBox(height: 6),
                SelectableText(
                  _spacedSas(state.sas!),
                  key: Key('mesh-sas-${peer.id}'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      key: Key('mesh-confirm-${peer.id}'),
                      onPressed: onConfirmPairing == null
                          ? null
                          : () {
                              onHaptic(MeshHapticEvent.confirmation);
                              onConfirmPairing!(peer, true);
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('Codes match'),
                    ),
                    TextButton(
                      key: Key('mesh-reject-${peer.id}'),
                      onPressed: onConfirmPairing == null
                          ? null
                          : () {
                              onHaptic(MeshHapticEvent.warning);
                              onConfirmPairing!(peer, false);
                            },
                      child: const Text('Do not pair'),
                    ),
                  ],
                ),
              ],
              if (state.syncState != MeshSyncState.idle) ...[
                const SizedBox(height: 12),
                _SyncStatus(state: state),
              ],
              if (state.pairingState !=
                  MeshPairingState.awaitingConfirmation) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (!state.isTrusted &&
                        state.pairingState == MeshPairingState.unpaired)
                      FilledButton.tonalIcon(
                        key: Key('mesh-pair-${peer.id}'),
                        onPressed: onPair == null
                            ? null
                            : () {
                                onHaptic(MeshHapticEvent.selection);
                                onPair!(peer);
                              },
                        icon: const Icon(Icons.link),
                        label: const Text('Pair securely'),
                      ),
                    if (state.syncState == MeshSyncState.failed)
                      TextButton.icon(
                        key: Key('mesh-retry-${peer.id}'),
                        onPressed: onRetrySync == null
                            ? null
                            : () {
                                onHaptic(MeshHapticEvent.selection);
                                onRetrySync!(peer);
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    if (state.canBeam)
                      FilledButton.tonalIcon(
                        key: Key('mesh-beam-${peer.id}'),
                        onPressed: onBeam == null
                            ? null
                            : () {
                                onHaptic(MeshHapticEvent.selection);
                                onBeam!(peer);
                              },
                        icon: const Icon(Icons.near_me_outlined),
                        label: const Text('Beam'),
                      ),
                    if (state.isTrusted)
                      TextButton.icon(
                        key: Key('mesh-revoke-${peer.id}'),
                        onPressed: onRevoke == null
                            ? null
                            : () {
                                onHaptic(MeshHapticEvent.warning);
                                onRevoke!(peer);
                              },
                        icon: const Icon(Icons.link_off),
                        label: const Text('Revoke trust'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.state});

  final MeshPeerViewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.syncState == MeshSyncState.failed) {
      return Semantics(
        liveRegion: true,
        label: 'Sync failed. ${state.syncError ?? 'Try again.'}',
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.syncError ?? 'Sync failed. Try again.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }
    if (state.syncState == MeshSyncState.complete) {
      return const Row(
        children: [
          Icon(Icons.check_circle_outline),
          SizedBox(width: 8),
          Text('Up to date'),
        ],
      );
    }
    return Semantics(
      liveRegion: true,
      value: '${(state.syncProgress * 100).round()} percent',
      label: 'Syncing with ${state.peer.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Syncing ${(state.syncProgress * 100).round()}%'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: Key('mesh-sync-progress-${state.peer.id}'),
            value: state.syncProgress,
          ),
        ],
      ),
    );
  }
}

String _availabilityLabel(MeshAvailability availability) =>
    switch (availability) {
      MeshAvailability.unavailable => 'Local mesh is unavailable',
      MeshAvailability.scanning => 'Scanning locally — no cloud required',
      MeshAvailability.available => 'Local mesh is available',
    };

String _syncLabel(MeshPeerViewState state) => switch (state.syncState) {
  MeshSyncState.idle => 'not syncing',
  MeshSyncState.syncing =>
    'syncing ${(state.syncProgress * 100).round()} percent',
  MeshSyncState.complete => 'up to date',
  MeshSyncState.failed => 'sync failed',
};

String _spacedSas(String value) {
  if (value.length != 6) return value;
  return '${value.substring(0, 3)} ${value.substring(3)}';
}
