import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_models.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_store.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_workflow_runner.dart';
import 'package:voicememory_mobile/features/catalyst_engine/ui/catalyst_studio_sheet.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('toggles recipes and renders execution history', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = CatalystStore(
      EncryptedJsonFileStore(
        file: File('${Directory.systemTemp.path}/unused-catalyst-widget.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    final runner = CatalystWorkflowRunner(store: store, bindings: _bindings());
    final recipe = CatalystRecipe(
      id: 'widget-recipe',
      name: 'Widget Recipe',
      enabled: false,
      trigger: const CatalystTrigger(CatalystTriggerKind.manual),
      actions: const [
        CatalystAction(id: 'muse', kind: CatalystActionKind.museSweep),
      ],
    );
    final run = CatalystRunLog(
      id: 'run-1',
      recipeId: recipe.id,
      eventId: 'event-1',
      status: CatalystRunStatus.succeeded,
      startedAt: DateTime.utc(2026),
      finishedAt: DateTime.utc(2026),
      completedActionIds: const ['muse'],
      message: 'Completed locally.',
    );
    CatalystRecipe? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalystStudioSheet(
            store: store,
            runner: runner,
            initialState: CatalystState(recipes: [recipe], runs: [run]),
            saveRecipe: (value) async => saved = value,
            authorizeOwner: (_) async => true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('catalyst-studio-sheet')), findsOneWidget);
    expect(find.byKey(const Key('catalyst-execution-log')), findsOneWidget);
    expect(find.text('Completed locally.'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('catalyst-recipe-toggle-widget-recipe')),
    );
    await tester.pump();

    expect(saved?.enabled, isTrue);
    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('catalyst-recipe-toggle-widget-recipe')),
          )
          .value,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

CatalystActionBindings _bindings() {
  Future<String?> action(Map<String, Object?> _) async => 'ok';
  return CatalystActionBindings(
    tagNode: action,
    rebuildClusters: action,
    queueOrphanBridge: action,
    councilPrompt: action,
    encryptedExport: action,
    museSweep: action,
    vaultHygiene: action,
  );
}
