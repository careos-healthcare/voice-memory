import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cognitive_analytics/cognitive_metrics_models.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_audit_store.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_data_connector.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_enclave_service.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_models.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_runtime_backend.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/ui/sandbox_studio_sheet.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/wasm_sandbox_manager.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('runs a trusted module and formats isolated output', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1700);
    tester.view.devicePixelRatio = 1;
    final service = SandboxEnclaveService(
      manager: WasmSandboxManager(backend: _UiBackend()),
      connector: SandboxDataConnector.loaders(
        graphLoader: () async => throw UnimplementedError(),
        metricsLoader: () async => CognitiveMetricsSnapshot(
          range: CognitiveTimeRange.allTime,
          points: const [],
          insights: const [],
        ),
      ),
      auditStore: SandboxAuditStore(
        EncryptedJsonFileStore(
          file: File(
            '${Directory.systemTemp.path}/unused-sandbox-widget-audit.enc',
          ),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      ),
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SandboxStudioSheet(
            service: service,
            initialSnapshot: const SandboxEnclaveSnapshot(
              capabilities: [
                SandboxRuntimeCapability(
                  kind: SandboxRuntimeKind.wasmtime,
                  available: true,
                  contractVersion: 1,
                  backend: 'test-runtime',
                  reason: '',
                ),
                SandboxRuntimeCapability.unavailable(
                  SandboxRuntimeKind.pyodide,
                  'not packaged',
                ),
                SandboxRuntimeCapability.unavailable(
                  SandboxRuntimeKind.javascript,
                  'not packaged',
                ),
              ],
              running: false,
              audits: [],
            ),
            runOverride: (_, _) async => SandboxExecutionResult(
              status: SandboxJobStatus.succeeded,
              moduleId: 'aggregate-metrics',
              console: 'isolated console output',
              elapsed: const Duration(milliseconds: 3),
              peakMemoryBytes: 4096,
              fuelConsumed: 42,
              artifact: SandboxArtifact(
                kind: SandboxArtifactKind.series,
                title: 'Local trend',
                values: const [1, 2, 3],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sandbox-source-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('sandbox-resource-meter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sandbox-run')));
    await tester.pump();
    await tester.pump();

    expect(find.text('isolated console output'), findsOneWidget);
    expect(find.byKey(const Key('sandbox-render-artifact')), findsOneWidget);
    expect(find.text('Local trend'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

final class _UiBackend implements SandboxRuntimeBackend {
  @override
  Future<SandboxRuntimeCapability> capability() async =>
      const SandboxRuntimeCapability(
        kind: SandboxRuntimeKind.wasmtime,
        available: true,
        contractVersion: 1,
        backend: 'test-runtime',
        reason: '',
      );

  @override
  Future<SandboxRuntimeJob> start({
    required TrustedSandboxModule module,
    required Uint8List input,
    required SandboxExecutionBudget budget,
  }) async => _UiJob();
}

final class _UiJob implements SandboxRuntimeJob {
  @override
  Future<SandboxBackendPoll> poll() async => SandboxBackendPoll(
    finished: true,
    succeeded: true,
    output: Uint8List.fromList(
      utf8.encode(
        '{"console":"isolated console output","artifact":'
        '{"kind":"series","title":"Local trend","values":[1,2,3]}}',
      ),
    ),
    fuelConsumed: 42,
    peakMemoryBytes: 4096,
  );

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
