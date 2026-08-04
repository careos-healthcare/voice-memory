import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/persona_forge/persona_forge_service.dart';
import 'package:voicememory_mobile/features/persona_forge/persona_knowledge_router.dart';
import 'package:voicememory_mobile/features/persona_forge/ui/persona_studio_sheet.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('validates form and persists slider and cluster permissions', (
    tester,
  ) async {
    final harness = await _WidgetHarness.create();
    addTearDown(harness.dispose);
    await harness.pump(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('persona-save')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('persona-name')),
      'Focus Guide',
    );
    await tester.enterText(
      find.byKey(const Key('persona-archetype')),
      'Deep work coach',
    );
    await tester.enterText(
      find.byKey(const Key('persona-prompt')),
      'Help me protect focused work using only permitted evidence.',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('persona-save')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('persona-cluster-focus')));
    await tester.drag(
      find.byKey(const Key('persona-temperature')),
      const Offset(120, 0),
    );
    await tester.tap(find.byKey(const Key('persona-save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final saved = (await harness.service.list()).single;
    expect(saved.restrictedClusterIds, {'focus'});
    expect(saved.temperature, greaterThan(.5));
  });

  testWidgets('sandbox responds using a scoped non-retained request', (
    tester,
  ) async {
    final harness = await _WidgetHarness.create();
    addTearDown(harness.dispose);
    PersonaInvocationRequest? captured;
    await harness.pump(
      tester,
      responder: (request) async {
        captured = request;
        return 'Scoped response ready.';
      },
    );
    await tester.enterText(
      find.byKey(const Key('persona-name')),
      'Focus Guide',
    );
    await tester.enterText(
      find.byKey(const Key('persona-archetype')),
      'Deep work coach',
    );
    await tester.enterText(
      find.byKey(const Key('persona-prompt')),
      'Use only permitted focus evidence.',
    );
    await tester.tap(find.byKey(const Key('persona-cluster-focus')));
    await tester.ensureVisible(
      find.byKey(const Key('persona-playground-input')),
    );
    await tester.enterText(
      find.byKey(const Key('persona-playground-input')),
      'What should I prioritize?',
    );
    await tester.tap(find.byKey(const Key('persona-playground-send')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Scoped response ready.'), findsOneWidget);
    expect(captured?.toJson()['store'], isFalse);
    expect(captured?.context.clusters.single['id'], 'focus');
  });
}

final class _WidgetHarness {
  _WidgetHarness({
    required this.root,
    required this.service,
    required this.semanticStore,
    required this.clusterStore,
    required this.router,
    required this.clusters,
  });

  final Directory root;
  final PersonaForgeService service;
  final LocalSemanticStore semanticStore;
  final SemanticClusterStore clusterStore;
  final PersonaKnowledgeRouter router;
  final List<SemanticCluster> clusters;

  static Future<_WidgetHarness> create() async {
    final root = Directory.systemTemp.createTempSync('persona_widget_test_');
    final service = PersonaForgeService.open(
      databasePath: '${root.path}/personas.sqlite3',
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
    final semanticStore = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    final clusterStore = SemanticClusterStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/clusters.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    final clusters = [
      SemanticCluster(
        id: 'focus',
        title: 'Focus',
        category: SemanticClusterCategory.project,
        nodeIds: const ['focus-node'],
        activityVelocity: .5,
        confidenceScore: .9,
      ),
    ];
    final router = PersonaKnowledgeRouter(
      semanticStore: semanticStore,
      clusterStore: clusterStore,
      clusterLoader: () async => clusters,
      semanticSearch:
          (query, {required allowedNodeIds, required limit}) async => const [],
      graphLoader: () async => PersonalKnowledgeGraph(),
    );
    return _WidgetHarness(
      root: root,
      service: service,
      semanticStore: semanticStore,
      clusterStore: clusterStore,
      router: router,
      clusters: clusters,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    PersonaPlaygroundResponder? responder,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonaStudioSheet(
            service: service,
            knowledgeRouter: router,
            clusters: clusters,
            playgroundResponder: responder,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void dispose() {
    service.close();
    clusterStore.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
