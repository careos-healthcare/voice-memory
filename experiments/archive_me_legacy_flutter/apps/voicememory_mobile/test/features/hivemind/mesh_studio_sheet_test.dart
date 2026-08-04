import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermal/thermal.dart';
import 'package:voicememory_mobile/features/hivemind/hivemind_models.dart';
import 'package:voicememory_mobile/features/hivemind/ui/mesh_studio_sheet.dart';
import 'package:voicememory_mobile/services/p2p_mesh/offload_policy_engine.dart';

void main() {
  testWidgets('renders peer topology and updates offload controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var governance = const HivemindGovernance(
      discoveryEnabled: true,
      automaticSyncEnabled: true,
    );
    final policy = OffloadPolicyEngine.forTesting();
    addTearDown(policy.dispose);
    policy
      ..updateBattery(level: 72, state: BatteryState.discharging)
      ..updateConnectivity(const [ConnectivityResult.wifi])
      ..updateAnchorPing(const Duration(milliseconds: 42), connected: true)
      ..updateThermalStatus(ThermalStatus.none);
    var reconciliations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeshStudioSheet(
            peers: const [
              HivemindPeerState(
                peerId: 'anchor-1',
                displayName: 'Studio Mac',
                deviceKind: HivemindDeviceKind.desktop,
                latency: Duration(milliseconds: 12),
                throughputBytesPerSecond: 2 * 1024 * 1024,
                offloadAccepted: true,
              ),
            ],
            capabilities: const [
              HivemindTransportCapability(
                kind: HivemindTransportKind.webRtc,
                available: true,
                contractVersion: 1,
                backend: 'local-webrtc-dtls-data-channel',
                reason: '',
              ),
            ],
            governance: governance,
            policyEngine: policy,
            onGovernanceChanged: (value) async => governance = value,
            onReconcile: () async => reconciliations++,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('mesh-network-topology')), findsOneWidget);
    expect(find.byKey(const Key('mesh-peer-anchor-1')), findsOneWidget);
    expect(find.textContaining('12 ms'), findsOneWidget);
    expect(find.textContaining('2.0 MB/s'), findsOneWidget);
    expect(find.text('Thermal nominal'), findsOneWidget);
    expect(find.textContaining('Battery 72%'), findsOneWidget);
    expect(find.text('Anchor 42 ms'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mesh-offload-toggle')));
    await tester.pump();
    expect(governance.computeOffloadEnabled, isTrue);

    await tester.tap(find.byKey(const Key('mesh-reconcile-now')));
    await tester.pump();
    expect(reconciliations, 1);
  });
}
