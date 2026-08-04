import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/codex_press/codex_compiler.dart';
import 'package:voicememory_mobile/features/codex_press/codex_encryption_manager.dart';
import 'package:voicememory_mobile/features/codex_press/codex_publication_service.dart';
import 'package:voicememory_mobile/features/codex_press/codex_renderers.dart';
import 'package:voicememory_mobile/features/codex_press/ui/codex_publish_sheet.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('shows template, organization, cluster, and export workflow', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('codex-widget-');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final cluster = SemanticCluster(
      id: 'local-theme',
      title: 'Local Theme',
      category: SemanticClusterCategory.theme,
      nodeIds: const ['node'],
      activityVelocity: 0,
      confidenceScore: 1,
      summary: 'A source-bound local theme.',
    );
    final service = CodexPublicationService(
      compiler: CodexCompiler.loaders(
        graphLoader: () async => PersonalKnowledgeGraph(),
        clusterLoader: () async => [cluster],
        journalLoader: () async => [],
        audioLoader: () async => [],
        transcriptLoader: (_) async => null,
        clock: () => DateTime.utc(2026),
      ),
      renderer: const CodexRenderer(),
      encryptionManager: CodexEncryptionManager(
        random: Random(2),
        passwordIterations: 1000,
        recoveryKeyProvider: () async => null,
      ),
      history: CodexPublicationHistoryStore(
        EncryptedJsonFileStore(
          file: File('${root.path}/history.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      ),
      exportsDirectory: Directory('${root.path}/exports'),
      authenticateOwner: (_) async => true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 900,
            child: CodexPublishSheet(service: service, clusters: [cluster]),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Thematic'));
    await tester.pump();
    expect(find.byKey(const Key('codex_cluster_local-theme')), findsOneWidget);
    expect(find.byKey(const Key('codex_template')), findsOneWidget);
    expect(find.text('Local Theme'), findsWidgets);
    expect(find.byKey(const Key('codex_source_selector')), findsOneWidget);
  });
}
