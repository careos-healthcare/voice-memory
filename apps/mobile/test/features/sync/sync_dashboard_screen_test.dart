import 'dart:async';

import 'package:archiveme_mobile/features/sync/sync_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop shows a pairing code and live peers and progress', (
    tester,
  ) async {
    final peers = StreamController<List<LanPeer>>.broadcast();
    final progress = StreamController<SyncProgressItem>.broadcast();
    addTearDown(peers.close);
    addTearDown(progress.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lanDiscoverySourceProvider.overrideWithValue(
            LanDiscoverySource(() => peers.stream),
          ),
          syncProgressSourceProvider.overrideWithValue(
            SyncProgressSource(() => progress.stream),
          ),
        ],
        child: const MaterialApp(home: SyncDashboardScreen()),
      ),
    );

    expect(find.byKey(const Key('pairing_qr')), findsOneWidget);
    expect(find.text('No peers on this network yet.'), findsOneWidget);

    peers.add(const [LanPeer(name: 'Studio', host: 'studio.local')]);
    progress.add(
      const SyncProgressItem(
        phase: SyncIsolatePhase.diffingHashes,
        detail: '12 entries',
      ),
    );
    progress.add(
      const SyncProgressItem(
        phase: SyncIsolatePhase.transferringEmbeddings,
        detail: '384 dimensions',
      ),
    );
    progress.add(
      const SyncProgressItem(
        phase: SyncIsolatePhase.finalizingVault,
        detail: 'archive write',
      ),
    );
    await tester.pump();

    expect(find.text('Studio · studio.local'), findsOneWidget);
    expect(find.textContaining('Comparing entry hashes'), findsOneWidget);
    expect(find.textContaining('Sending search embeddings'), findsOneWidget);
    expect(find.textContaining('Writing the archive'), findsOneWidget);
  });

  testWidgets('a scanned desktop code becomes a trusted peer', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SyncDashboardScreen(role: SyncDashboardRole.mobile),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('pairing_scan_entry')),
      'archiveme-pair:Desktop:abcd1234',
    );
    await tester.tap(find.byKey(const Key('pairing_scan_submit')));
    await tester.pump();

    expect(find.byKey(const Key('trusted_peer_Desktop')), findsOneWidget);
  });
}
