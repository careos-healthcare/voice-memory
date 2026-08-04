import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/hivemind/hivemind_models.dart';
import 'package:voicememory_mobile/features/hivemind/ui/hivemind_status_sheet.dart';
import 'package:voicememory_mobile/shared/ui/glassmorphic_container.dart';

void main() {
  testWidgets(
    'renders topology, unavailable contracts, and updates governance',
    (tester) async {
      var governance = const HivemindGovernance(discoveryEnabled: true);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: GlassRenderPolicyScope(
                child: HivemindStatusSheet(
                  peers: const [
                    HivemindPeerState(
                      peerId: 'mac',
                      displayName: 'MacBook Pro',
                      deviceKind: HivemindDeviceKind.desktop,
                      gpuState: HivemindGpuState.idle,
                      latency: Duration(milliseconds: 8),
                    ),
                  ],
                  capabilities: const [
                    HivemindTransportCapability(
                      kind: HivemindTransportKind.nsdTcp,
                      available: true,
                      contractVersion: 1,
                      backend: 'encrypted-nsd-tcp',
                      reason: '',
                    ),
                    HivemindTransportCapability.unavailable(
                      HivemindTransportKind.noiseXX,
                      'Noise XX native transport is not packaged.',
                    ),
                  ],
                  governance: governance,
                  onGovernanceChanged: (value) async => governance = value,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('hivemind-topology')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hivemind-offload-toggle')));
      await tester.pump();
      expect(governance.computeOffloadEnabled, isTrue);

      await tester.scrollUntilVisible(
        find.text('MacBook Pro'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.textContaining('Noise XX native'), findsOneWidget);
    },
  );
}

final class GlassRenderPolicyScope extends StatelessWidget {
  const GlassRenderPolicyScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GlassmorphicContainer(
    renderQuality: GlassRenderQuality.off,
    padding: EdgeInsets.zero,
    child: child,
  );
}
