import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_models.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_store.dart';
import 'package:voicememory_mobile/features/catalyst_engine/catalyst_workflow_runner.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('runs matching multi-step workflows in deterministic order', () async {
    final harness = _Harness();
    final calls = <String>[];
    final runner = CatalystWorkflowRunner(
      store: harness.store,
      bindings: harness.bindings(calls: calls),
    );
    final recipe = CatalystRecipe(
      id: 'ordered',
      name: 'Ordered',
      trigger: const CatalystTrigger(CatalystTriggerKind.manual),
      conditions: const [
        CatalystCondition(
          field: 'score',
          operator: CatalystConditionOperator.greaterThan,
          value: 2,
        ),
      ],
      actions: const [
        CatalystAction(id: 'tag', kind: CatalystActionKind.tagNode),
        CatalystAction(id: 'cluster', kind: CatalystActionKind.rebuildClusters),
      ],
    );

    final run = await runner.execute(recipe, _event({'score': 3}));

    expect(run.status, CatalystRunStatus.succeeded);
    expect(calls, ['tagNode', 'rebuildClusters']);
    expect(run.completedActionIds, ['tag', 'cluster']);
    await harness.dispose();
  });

  test('enforces action timeout and owner approval resume', () async {
    final harness = _Harness();
    final timeoutRunner = CatalystWorkflowRunner(
      store: harness.store,
      bindings: harness.bindings(delay: const Duration(milliseconds: 50)),
    );
    final timeoutRecipe = CatalystRecipe(
      id: 'timeout',
      name: 'Timeout',
      trigger: const CatalystTrigger(CatalystTriggerKind.manual),
      actions: const [
        CatalystAction(
          id: 'slow',
          kind: CatalystActionKind.tagNode,
          timeout: Duration(milliseconds: 5),
        ),
      ],
    );
    expect(
      (await timeoutRunner.execute(timeoutRecipe, _event())).status,
      CatalystRunStatus.timedOut,
    );

    final approvalRecipe = CatalystRecipe(
      id: 'approval',
      name: 'Approval',
      trigger: const CatalystTrigger(CatalystTriggerKind.manual),
      actions: const [
        CatalystAction(
          id: 'delete-audio',
          kind: CatalystActionKind.vaultHygiene,
        ),
      ],
    );
    await harness.store.saveRecipe(approvalRecipe);
    final runner = CatalystWorkflowRunner(
      store: harness.store,
      bindings: harness.bindings(),
    );
    final pending = await runner.execute(approvalRecipe, _event());
    expect(pending.status, CatalystRunStatus.awaitingApproval);
    final approval = (await harness.store.read()).approvals.single;
    final resumed = await runner.approve(approval.id);
    expect(resumed.status, CatalystRunStatus.succeeded);
    expect((await harness.store.read()).approvals, isEmpty);
    await harness.dispose();
  });

  test('dry run does not invoke handlers', () async {
    final harness = _Harness();
    final calls = <String>[];
    final runner = CatalystWorkflowRunner(
      store: harness.store,
      bindings: harness.bindings(calls: calls),
    );
    final recipe = CatalystRecipe(
      id: 'dry',
      name: 'Dry',
      trigger: const CatalystTrigger(CatalystTriggerKind.manual),
      actions: const [
        CatalystAction(id: 'muse', kind: CatalystActionKind.museSweep),
      ],
    );

    final run = await runner.execute(recipe, _event(), dryRun: true);
    expect(run.status, CatalystRunStatus.dryRun);
    expect(calls, isEmpty);
    await harness.dispose();
  });

  test('sandbox dry run reports capability without executing', () async {
    final harness = _Harness();
    final calls = <String>[];
    final runner = CatalystWorkflowRunner(
      store: harness.store,
      bindings: harness.bindings(
        calls: calls,
        preflight: (_) async => const CatalystActionPreflightResult(
          available: false,
          summary: 'Wasmtime is not packaged; 16 MiB memory limit.',
        ),
      ),
    );
    final recipe = CatalystRecipe(
      id: 'sandbox',
      name: 'Sandbox',
      trigger: const CatalystTrigger(CatalystTriggerKind.manual),
      actions: const [
        CatalystAction(
          id: 'module',
          kind: CatalystActionKind.sandboxModule,
          arguments: {
            'moduleId': 'aggregate-metrics',
            'dataGrant': 'cognitiveMetrics',
          },
        ),
      ],
    );

    final dryRun = await runner.execute(recipe, _event(), dryRun: true);
    expect(dryRun.status, CatalystRunStatus.dryRun);
    expect(dryRun.output, contains('Wasmtime is not packaged'));
    expect(calls, isEmpty);
    expect(
      (await runner.execute(recipe, _event())).status,
      CatalystRunStatus.capabilityUnavailable,
    );
    await harness.dispose();
  });
}

CatalystEvent _event([Map<String, Object?> payload = const {}]) =>
    CatalystEvent(
      id: 'event-${payload.hashCode}',
      kind: CatalystTriggerKind.manual,
      occurredAt: DateTime.utc(2026, 1, 1),
      payload: payload,
    );

final class _Harness {
  _Harness() : root = Directory.systemTemp.createTempSync('catalyst-runner-') {
    store = CatalystStore(
      EncryptedJsonFileStore(
        file: File('${root.path}/state.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
  }

  final Directory root;
  late final CatalystStore store;

  CatalystActionBindings bindings({
    List<String>? calls,
    Duration delay = Duration.zero,
    CatalystActionPreflight? preflight,
  }) {
    Future<String?> call(String name, Map<String, Object?> _) async {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      calls?.add(name);
      return name;
    }

    return CatalystActionBindings(
      tagNode: (value) => call('tagNode', value),
      rebuildClusters: (value) => call('rebuildClusters', value),
      queueOrphanBridge: (value) => call('queueOrphanBridge', value),
      councilPrompt: (value) => call('councilPrompt', value),
      encryptedExport: (value) => call('encryptedExport', value),
      museSweep: (value) => call('museSweep', value),
      vaultHygiene: (value) => call('vaultHygiene', value),
      sandboxModule: (value) => call('sandboxModule', value),
      preflight: preflight,
    );
  }

  Future<void> dispose() async {
    await store.dispose();
    root.deleteSync(recursive: true);
  }
}
