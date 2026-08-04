import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/mesh_exchange/mesh_exchange_models.dart';
import 'package:voicememory_mobile/features/mesh_exchange/mesh_exchange_service.dart';
import 'package:voicememory_mobile/features/mesh_exchange/mesh_import_validator.dart';
import 'package:voicememory_mobile/features/mesh_exchange/ui/mesh_exchange_sheet.dart';
import 'package:voicememory_mobile/services/security/mesh_identity_service.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('scanner progresses to diff and approval flow', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = Directory.systemTemp.createTempSync('mesh_sheet_test_');
    final exchange = MeshExchangeService(
      identity: MeshIdentityService(
        store: MemorySyncIdentityStore(),
        deviceIdProvider: () async => 'receiver',
      ),
    );
    final store = MeshIncomingStore.open(
      databasePath: '${root.path}/incoming.sqlite3',
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
    final validator = MeshImportValidator(exchange: exchange, store: store);
    final content = MeshExchangeContent(
      id: 'exchange',
      senderName: 'Alice',
      graph: PersonalKnowledgeGraph(),
      policy: MeshExchangePolicy.reusable,
      createdAt: DateTime.utc(2026),
    );
    final diff = MeshImportDiff(
      content: content,
      signerFingerprint: 'fingerprint',
      newNodeIds: const [],
      conflictingNodeIds: const ['existing'],
      newPersonaIds: const [],
      conflictingPersonaIds: const [],
    );
    final frame = exchange
        .qrFrames(
          Uint8List.fromList([1, 2, 3]),
          exchangeId: 'exchange',
          payloadCharacters: 128,
        )
        .single
        .encode();
    var approved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeshExchangeSheet(
            exchange: exchange,
            validator: validator,
            graph: PersonalKnowledgeGraph(),
            clusters: const [],
            personas: const [],
            scannerBuilder: (onPayload) => Center(
              child: FilledButton(
                key: const Key('fake-scan-frame'),
                onPressed: () => onPayload(frame),
                child: const Text('Decode frame'),
              ),
            ),
            diffLoader: (_) async => diff,
            diffApprover: (_) async => approved = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Import'));
    await tester.pump();
    expect(find.byKey(const Key('mesh-import-handshake')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mesh-start-scanner')));
    await tester.pump();
    expect(find.byKey(const Key('mesh-import-scanner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fake-scan-frame')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('mesh-import-diff')), findsOneWidget);
    expect(find.byKey(const Key('mesh-conflict-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mesh-approve-import')));
    await tester.pump();
    expect(approved, isTrue);
    expect(
      find.textContaining('imported as an isolated branch'),
      findsOneWidget,
    );

    store.close();
    exchange.dispose();
    root.deleteSync(recursive: true);
  });
}
