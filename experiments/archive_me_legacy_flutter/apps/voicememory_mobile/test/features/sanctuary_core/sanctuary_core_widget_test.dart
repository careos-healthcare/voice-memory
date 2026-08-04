import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/sanctuary_core/sanctuary_models.dart';
import 'package:voicememory_mobile/features/sanctuary_core/ui/keyring_manager_sheet.dart';
import 'package:voicememory_mobile/features/sanctuary_core/ui/sanctuary_core_dashboard.dart';

void main() {
  testWidgets('keyring gates phrase disclosure and verifies recovery words', (
    tester,
  ) async {
    var allowAuthentication = false;
    var revealAttempts = 0;
    String? verifiedCandidate;
    const phrase =
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyringManagerSheet(
            revealPhrase: () async {
              revealAttempts++;
              return allowAuthentication ? phrase : null;
            },
            verifyPhrase: (candidate) async {
              verifiedCandidate = candidate;
              return allowAuthentication && candidate == phrase;
            },
            rotateSyncKey: () async => phrase,
            exportKeys: (_) async => File('/tmp/test.sanctuary-key'),
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('sanctuary-reveal-phrase')));
    await tester.pump();
    expect(find.byKey(const Key('sanctuary-recovery-words')), findsNothing);
    expect(revealAttempts, 1);

    allowAuthentication = true;
    await tester.tap(find.byKey(const Key('sanctuary-reveal-phrase')));
    await tester.pump();
    expect(find.byKey(const Key('sanctuary-recovery-words')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('sanctuary-verify-field')),
      phrase,
    );
    await tester.tap(find.byKey(const Key('sanctuary-verify-phrase')));
    await tester.pump();
    expect(verifiedCandidate, phrase);
  });

  testWidgets('dashboard applies governance and executes confirmed wipe', (
    tester,
  ) async {
    final toggles = <String>[];
    var wipeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SanctuaryCoreDashboard(
            loadReport: () async => _report(),
            initialGovernance: const SanctuaryGovernanceState(
              museEnabled: true,
              browserBridgeEnabled: false,
              peerDiscoveryEnabled: false,
            ),
            onMuseChanged: (value) async => toggles.add('muse:$value'),
            onBrowserBridgeChanged: (value) async =>
                toggles.add('browser:$value'),
            onPeerDiscoveryChanged: (value) async => toggles.add('mesh:$value'),
            authorizeWipe: () async => true,
            onEmergencyWipe: () async {
              wipeCount++;
              return true;
            },
            onOpenKeyring: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('sanctuary-browser-toggle')));
    await tester.pump();
    expect(toggles, contains('browser:true'));

    await tester.scrollUntilVisible(
      find.byKey(const Key('sanctuary-nuclear-wipe')),
      350,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('sanctuary-nuclear-wipe')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sanctuary-wipe-confirm-field')),
      'WIPE MY SANCTUARY',
    );
    await tester.tap(find.byKey(const Key('sanctuary-wipe-confirm')));
    await tester.pump();
    expect(wipeCount, 1);
  });
}

SanctuaryHealthReport _report() => SanctuaryHealthReport(
  generatedAt: DateTime.utc(2026, 7, 28),
  diagnostics: const [
    SanctuaryDiagnostic(
      id: 'key',
      label: 'Encryption key',
      status: SanctuaryCheckStatus.healthy,
      detail: 'Valid',
    ),
  ],
  storage: const [
    SanctuaryStorageMetric(
      kind: SanctuaryStorageKind.memoryGraph,
      bytes: 1024,
      itemCount: 2,
      label: 'Memory Graph',
    ),
  ],
  cleanupRecommendations: const [],
);
