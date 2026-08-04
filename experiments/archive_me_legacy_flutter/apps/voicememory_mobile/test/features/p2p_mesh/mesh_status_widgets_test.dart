import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_models.dart';
import 'package:voicememory_mobile/features/p2p_mesh/ui/mesh_status_overlay.dart';
import 'package:voicememory_mobile/features/p2p_mesh/ui/mesh_ui_models.dart';

void main() {
  testWidgets('status chip summarizes failures and opens details', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeshStatusOverlay(
            availability: MeshAvailability.available,
            peers: [
              MeshPeerViewState(
                peer: _peer('one', 'Living Room'),
                isTrusted: true,
                pairingState: MeshPairingState.paired,
                syncState: MeshSyncState.failed,
                syncError: 'Connection lost',
              ),
            ],
            onPressed: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Mesh needs attention'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mesh-status-overlay')));
    expect(opened, isTrue);
  });

  testWidgets('sheet confirms SAS and injects haptic callback', (tester) async {
    MeshPeer? confirmedPeer;
    bool? confirmed;
    final haptics = <MeshHapticEvent>[];
    await _pumpSheet(
      tester,
      peers: [
        MeshPeerViewState(
          peer: _peer('phone', 'Chirag’s Phone'),
          pairingState: MeshPairingState.awaitingConfirmation,
          sas: '123456',
        ),
      ],
      onConfirmPairing: (peer, matches) {
        confirmedPeer = peer;
        confirmed = matches;
      },
      onHaptic: haptics.add,
    );

    expect(find.text('123 456'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Radar showing 1 nearby peer'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mesh-confirm-phone')));
    expect(confirmedPeer?.id, 'phone');
    expect(confirmed, isTrue);
    expect(haptics, [MeshHapticEvent.confirmation]);
  });

  testWidgets('sheet starts secure pairing and exposes share import', (
    tester,
  ) async {
    final calls = <String>[];
    await _pumpSheet(
      tester,
      peers: [MeshPeerViewState(peer: _peer('new', 'Nearby device'))],
      onPair: (peer) => calls.add('pair:${peer.id}'),
      onImportShare: () => calls.add('import'),
      onShowQr: () => calls.add('show-qr'),
      onScanQr: () => calls.add('scan-qr'),
    );

    await tester.tap(find.byKey(const Key('mesh-pair-new')));
    await tester.tap(find.byKey(const Key('mesh-import-share')));
    await tester.tap(find.byKey(const Key('mesh-show-pairing-qr')));
    await tester.tap(find.byKey(const Key('mesh-scan-pairing-qr')));
    expect(calls, ['pair:new', 'import', 'show-qr', 'scan-qr']);
  });

  testWidgets('sheet exposes sync retry, beam, revoke and responsive scroll', (
    tester,
  ) async {
    final calls = <String>[];
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSheet(
      tester,
      peers: [
        MeshPeerViewState(
          peer: _peer('failed', 'Office Mac'),
          isTrusted: true,
          pairingState: MeshPairingState.paired,
          syncState: MeshSyncState.failed,
          syncError: 'Peer went offline',
        ),
        MeshPeerViewState(
          peer: _peer('ready', 'Tablet'),
          isTrusted: true,
          pairingState: MeshPairingState.paired,
          syncState: MeshSyncState.complete,
        ),
      ],
      onRetrySync: (peer) => calls.add('retry:${peer.id}'),
      onBeam: (peer) => calls.add('beam:${peer.id}'),
      onRevoke: (peer) => calls.add('revoke:${peer.id}'),
    );

    await tester.ensureVisible(find.byKey(const Key('mesh-retry-failed')));
    await tester.tap(find.byKey(const Key('mesh-retry-failed')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('mesh-beam-ready')),
      220,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('mesh-beam-ready')));
    await tester.ensureVisible(find.byKey(const Key('mesh-revoke-ready')));
    await tester.tap(find.byKey(const Key('mesh-revoke-ready')));
    expect(calls, ['retry:failed', 'beam:ready', 'revoke:ready']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion sheet has no repeating animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: MeshStatusSheet(
                availability: MeshAvailability.scanning,
                peers: [MeshPeerViewState(peer: _peer('one', 'Phone'))],
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mesh-radar')), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required List<MeshPeerViewState> peers,
  MeshPairingCallback? onConfirmPairing,
  MeshPeerCallback? onPair,
  MeshPeerCallback? onRetrySync,
  MeshPeerCallback? onRevoke,
  MeshPeerCallback? onBeam,
  MeshHapticCallback? onHaptic,
  VoidCallback? onImportShare,
  VoidCallback? onShowQr,
  VoidCallback? onScanQr,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 620,
            child: MeshStatusSheet(
              availability: MeshAvailability.available,
              peers: peers,
              onClose: () {},
              onConfirmPairing: onConfirmPairing,
              onPair: onPair,
              onRetrySync: onRetrySync,
              onRevoke: onRevoke,
              onBeam: onBeam,
              onHaptic: onHaptic,
              onImportShare: onImportShare,
              onShowQr: onShowQr,
              onScanQr: onScanQr,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MeshPeer _peer(String id, String name) => MeshPeer(
  id: id,
  name: name,
  host: '192.168.1.2',
  port: 4040,
  identityFingerprint: 'fingerprint-$id',
);
