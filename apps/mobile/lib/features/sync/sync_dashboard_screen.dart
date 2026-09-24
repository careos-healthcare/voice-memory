import 'dart:async';
import 'dart:math';

import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart';

/// A device seen on the local network.
class LanPeer {
  const LanPeer({required this.name, required this.host});

  final String name;
  final String host;
}

/// Steps the background sync isolate reports.
enum SyncIsolatePhase { diffingHashes, transferringEmbeddings, finalizingVault }

/// One row in the live sync list.
class SyncProgressItem {
  const SyncProgressItem({required this.phase, required this.detail});

  final SyncIsolatePhase phase;
  final String detail;

  String get label => switch (phase) {
    SyncIsolatePhase.diffingHashes => 'Comparing entry hashes',
    SyncIsolatePhase.transferringEmbeddings => 'Sending search embeddings',
    SyncIsolatePhase.finalizingVault => 'Writing the archive',
  };
}

/// Code shown on desktop and accepted on the phone.
class PairingTicket {
  const PairingTicket({required this.deviceName, required this.token});

  final String deviceName;
  final String token;

  String get payload => 'archiveme-pair:$deviceName:$token';

  static PairingTicket issue({String deviceName = 'Desktop', Random? random}) {
    final source = random ?? Random.secure();
    final token = List.generate(
      8,
      (_) => source.nextInt(16).toRadixString(16),
    ).join();
    return PairingTicket(deviceName: deviceName, token: token);
  }

  static PairingTicket? parse(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 3 || parts[0] != 'archiveme-pair') return null;
    if (parts[1].isEmpty || parts[2].length < 8) return null;
    return PairingTicket(deviceName: parts[1], token: parts[2]);
  }
}

/// mDNS/Bonjour peer list. The default stream stays empty until a host is set.
class LanDiscoverySource {
  const LanDiscoverySource(this.watch);

  final Stream<List<LanPeer>> Function() watch;

  static const idle = LanDiscoverySource(_empty);

  static Stream<List<LanPeer>> _empty() => const Stream.empty();
}

/// Progress events from the background sync isolate.
class SyncProgressSource {
  const SyncProgressSource(this.watch);

  final Stream<SyncProgressItem> Function() watch;

  static const idle = SyncProgressSource(_empty);

  static Stream<SyncProgressItem> _empty() => const Stream.empty();
}

final lanDiscoverySourceProvider = Provider<LanDiscoverySource>(
  (ref) => LanDiscoverySource.idle,
);

final syncProgressSourceProvider = Provider<SyncProgressSource>(
  (ref) => SyncProgressSource.idle,
);

/// Trusted peers plus the live isolate steps.
class SyncDashboardState {
  const SyncDashboardState({
    required this.ticket,
    required this.peers,
    required this.progress,
    required this.trustedNames,
  });

  final PairingTicket ticket;
  final List<LanPeer> peers;
  final List<SyncProgressItem> progress;
  final List<String> trustedNames;

  SyncDashboardState copyWith({
    List<LanPeer>? peers,
    List<SyncProgressItem>? progress,
    List<String>? trustedNames,
  }) {
    return SyncDashboardState(
      ticket: ticket,
      peers: peers ?? this.peers,
      progress: progress ?? this.progress,
      trustedNames: trustedNames ?? this.trustedNames,
    );
  }
}

/// Listens to discovery and the sync isolate, and records a scanned pair.
class SyncDashboardController extends Notifier<SyncDashboardState> {
  @override
  SyncDashboardState build() {
    final ticket = PairingTicket.issue(random: Random(1));
    final peersSub = ref.watch(lanDiscoverySourceProvider).watch().listen((
      peers,
    ) {
      state = state.copyWith(peers: peers);
    });
    final progressSub = ref.watch(syncProgressSourceProvider).watch().listen((
      item,
    ) {
      state = state.copyWith(progress: [...state.progress, item]);
    });
    ref.onDispose(() {
      unawaited(peersSub.cancel());
      unawaited(progressSub.cancel());
    });
    return SyncDashboardState(
      ticket: ticket,
      peers: const [],
      progress: const [],
      trustedNames: const [],
    );
  }

  /// Accepts a code scanned from the desktop QR.
  bool trustScannedPayload(String raw) {
    final ticket = PairingTicket.parse(raw);
    if (ticket == null) return false;
    if (state.trustedNames.contains(ticket.deviceName)) return true;
    state = state.copyWith(
      trustedNames: [...state.trustedNames, ticket.deviceName],
    );
    return true;
  }
}

final syncDashboardProvider =
    NotifierProvider<SyncDashboardController, SyncDashboardState>(
      SyncDashboardController.new,
    );

enum SyncDashboardRole { desktop, mobile }

/// Pairing code, LAN peers, and the live sync isolate list.
class SyncDashboardScreen extends ConsumerWidget {
  const SyncDashboardScreen({super.key, this.role = SyncDashboardRole.desktop});

  final SyncDashboardRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(syncDashboardProvider);
    return Scaffold(
      key: const Key('sync_dashboard_screen'),
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(title: const Text('Sync')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spacing6),
        children: [
          if (role == SyncDashboardRole.desktop)
            _DesktopPairing(ticket: dashboard.ticket)
          else
            _MobilePairing(
              trustedNames: dashboard.trustedNames,
              onScanned: (raw) => ref
                  .read(syncDashboardProvider.notifier)
                  .trustScannedPayload(raw),
            ),
          const SizedBox(height: AppTokens.spacing6),
          _LanPeerStatus(peers: dashboard.peers),
          const SizedBox(height: AppTokens.spacing6),
          _SyncProgressList(items: dashboard.progress),
        ],
      ),
    );
  }
}

class _DesktopPairing extends StatelessWidget {
  const _DesktopPairing({required this.ticket});

  final PairingTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pair this desktop', style: AppTokens.section()),
        const SizedBox(height: AppTokens.spacing2),
        const Text('Scan this code on your phone to trust this device.'),
        const SizedBox(height: AppTokens.spacing4),
        Center(child: _PairingQr(payload: ticket.payload)),
      ],
    );
  }
}

class _MobilePairing extends StatefulWidget {
  const _MobilePairing({required this.trustedNames, required this.onScanned});

  final List<String> trustedNames;
  final bool Function(String raw) onScanned;

  @override
  State<_MobilePairing> createState() => _MobilePairingState();
}

class _MobilePairingState extends State<_MobilePairing> {
  final _entry = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _submit() {
    final accepted = widget.onScanned(_entry.text);
    setState(() {
      _error = accepted ? null : 'That pairing code could not be read.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scan a desktop code', style: AppTokens.section()),
        const SizedBox(height: AppTokens.spacing2),
        const Text(
          'Point the camera at the desktop code, or paste the code it shows.',
        ),
        const SizedBox(height: AppTokens.spacing4),
        TextField(
          key: const Key('pairing_scan_entry'),
          controller: _entry,
          decoration: const InputDecoration(labelText: 'Pairing code'),
        ),
        if (_error != null) Text(_error!),
        const SizedBox(height: AppTokens.spacing2),
        FilledButton(
          key: const Key('pairing_scan_submit'),
          onPressed: _submit,
          child: const Text('Trust this device'),
        ),
        for (final name in widget.trustedNames)
          Text(name, key: Key('trusted_peer_$name')),
      ],
    );
  }
}

class _LanPeerStatus extends StatelessWidget {
  const _LanPeerStatus({required this.peers});

  final List<LanPeer> peers;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('lan_peer_status'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Devices on this network', style: AppTokens.section()),
        const SizedBox(height: AppTokens.spacing2),
        if (peers.isEmpty)
          const Text('No peers on this network yet.')
        else
          for (final peer in peers)
            Text(
              '${peer.name} · ${peer.host}',
              key: Key('lan_peer_${peer.name}'),
            ),
      ],
    );
  }
}

class _SyncProgressList extends StatelessWidget {
  const _SyncProgressList({required this.items});

  final List<SyncProgressItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('sync_progress_list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sync progress', style: AppTokens.section()),
        const SizedBox(height: AppTokens.spacing2),
        if (items.isEmpty)
          const Text('Waiting for the sync isolate.')
        else
          for (final item in items)
            Text(
              '${item.label}. ${item.detail}',
              key: Key('sync_phase_${item.phase.name}'),
            ),
      ],
    );
  }
}

class _PairingQr extends StatelessWidget {
  const _PairingQr({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    return CustomPaint(
      key: const Key('pairing_qr'),
      size: const Size(180, 180),
      painter: _QrPainter(image),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final cell = size.width / count;
    final paint = Paint()..color = const Color(0xFF111111);
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => false;
}
