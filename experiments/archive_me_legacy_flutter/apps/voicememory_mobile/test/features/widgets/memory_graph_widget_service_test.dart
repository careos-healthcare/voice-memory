import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_engine.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_store.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/features/widgets/memory_graph_widget_models.dart';
import 'package:voicememory_mobile/features/widgets/memory_graph_widget_service.dart';
import 'package:voicememory_mobile/features/widgets/ui/widget_settings_sheet.dart';
import 'package:voicememory_mobile/services/local_storage/shared_vault_storage.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late _Fixture fixture;

  setUp(() async {
    fixture = await _Fixture.create();
  });

  tearDown(() => fixture.dispose());

  test('publishes bounded privacy and lock-screen snapshot fields', () async {
    await fixture.service.savePreferences(
      const MemoryGraphWidgetPreferences(
        theme: MemoryGraphWidgetTheme.midnight,
        lockScreenEnabled: true,
      ),
    );

    final snapshot = fixture.platform.snapshots.single;
    expect(snapshot['schemaVersion'], 1);
    expect(snapshot['theme'], 'midnight');
    expect(snapshot['lockScreenEnabled'], isTrue);
    expect(snapshot['quickCapture'], isA<Map>());
    expect(snapshot['habits'], isA<List>());
    expect(snapshot['clusters'], isA<List>());
    expect(fixture.platform.reloadCount, 1);
  });

  test('semantic cluster pulse action requests a widget refresh', () async {
    fixture.platform.actions = [
      {'type': 'semanticClusterPulse', 'createdAt': 1},
    ];

    expect(await fixture.service.applyPendingActions(), 1);
    expect(fixture.platform.snapshots, hasLength(1));
    expect(fixture.platform.reloadCount, 1);
  });

  testWidgets('settings sheet surfaces pending encrypted share diagnostics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WidgetExtensionStatusCard(
            status: MemoryGraphWidgetStatus(
              shareExtensionAvailable: true,
              widgetExtensionAvailable: true,
              sharedContainerAvailable: true,
              lockScreenWidgetsSupported: true,
              pendingShareCount: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('2 encrypted shares pending import'),
      findsOneWidget,
    );
    expect(find.textContaining('Lock Screen widget surfaces'), findsOneWidget);
  });
}

class _Fixture {
  _Fixture({
    required this.directory,
    required this.planStore,
    required this.clusterStore,
    required this.graphStore,
    required this.platform,
    required this.service,
  });

  final Directory directory;
  final ActionPlanStore planStore;
  final SemanticClusterStore clusterStore;
  final PersonalKnowledgeGraphStore graphStore;
  final _WidgetPlatform platform;
  final MemoryGraphWidgetService service;

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'widget-service-test',
    );
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    await keyStore.ensureKey();
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${directory.path}/$name.enc'),
      keyStore: keyStore,
    );
    final planStore = ActionPlanStore(storage: encrypted('plans'));
    final clusterStore = SemanticClusterStore(storage: encrypted('clusters'));
    final graphStore = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final engine = ActionPlanEngine(store: planStore, graphStore: graphStore);
    final journal = await JournalStore.open(
      '${directory.path}/journal.json',
      encryptAtRest: false,
      syncDeviceIdProvider: () async => 'widget-test-device',
    );
    final prefs = await MobilePrefsStore.open('${directory.path}/prefs.json');
    final platform = _WidgetPlatform();
    final service = MemoryGraphWidgetService(
      actionPlanStore: planStore,
      actionPlanEngine: engine,
      clusterStore: clusterStore,
      journalStore: journal,
      preferencesStore: prefs,
      platform: platform,
      clock: () => DateTime(2026, 7, 28, 8),
    );
    return _Fixture(
      directory: directory,
      planStore: planStore,
      clusterStore: clusterStore,
      graphStore: graphStore,
      platform: platform,
      service: service,
    );
  }

  Future<void> dispose() async {
    planStore.dispose();
    clusterStore.dispose();
    await graphStore.dispose();
    await directory.delete(recursive: true);
  }
}

class _WidgetPlatform implements SharedVaultPlatformBridge {
  List<Map<String, Object?>> actions = const [];
  final List<Map<String, Object?>> snapshots = [];
  int reloadCount = 0;

  @override
  Future<List<Map<String, Object?>>> drainWidgetActions() async => actions;

  @override
  Future<void> publishWidgetSnapshot(Map<String, Object?> snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Future<void> reloadWidgets() async {
    reloadCount++;
  }

  @override
  Future<Map<String, Object?>> extensionStatus() async => const {
    'shareExtensionAvailable': true,
    'widgetExtensionAvailable': true,
    'sharedContainerAvailable': true,
    'lockScreenWidgetsSupported': true,
    'pendingShareCount': 2,
  };

  @override
  Future<void> acknowledgeNativeInbox(
    Iterable<SharedVaultPayload> imported,
  ) async {}

  @override
  Future<List<SharedVaultPayload>> drainNativeInbox() async => const [];

  @override
  Future<String?> sharedContainerPath() async => null;
}
