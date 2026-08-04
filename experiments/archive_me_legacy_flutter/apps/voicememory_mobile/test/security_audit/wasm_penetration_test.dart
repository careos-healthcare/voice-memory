import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_models.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_runtime_backend.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/wasm_sandbox_manager.dart';

void main() {
  test(
    'environment-variable import is rejected before runtime dispatch',
    () async {
      final bytes = _importModule('wasi_snapshot_preview1', 'environ_get');
      final backend = _PenetrationBackend();
      final manager = WasmSandboxManager(
        backend: backend,
        registry: TrustedSandboxRegistry([
          TrustedSandboxModule(
            manifest: SandboxModuleManifest(
              id: 'environment-probe',
              version: 1,
              displayName: 'Environment probe',
              sha256: sha256.convert(bytes).toString(),
              entrypoint: 'run',
              allowedImports: const {},
              dataGrants: const {},
            ),
            bytes: bytes,
          ),
        ]),
      );

      final result = await manager.execute(_request('environment-probe'));

      expect(result.status, SandboxJobStatus.failed);
      expect(result.reason, contains('undeclared host import'));
      expect(backend.started, isFalse);
      await manager.dispose();
    },
  );

  test(
    'infinite-loop simulation is cancelled at the wall-clock limit',
    () async {
      final backend = _PenetrationBackend(neverFinishes: true);
      final manager = WasmSandboxManager(backend: backend);

      final result = await manager.execute(
        _request(
          'aggregate-metrics',
          budget: const SandboxExecutionBudget(
            timeout: Duration(milliseconds: 25),
          ),
        ),
      );

      expect(result.status, SandboxJobStatus.timedOut);
      expect(backend.job.cancelled, isTrue);
      expect(backend.job.disposed, isTrue);
      await manager.dispose();
    },
  );

  test('memory allocation and fuel bombs fail closed', () async {
    const budget = SandboxExecutionBudget(
      maximumMemoryBytes: 64 * 1024,
      maximumFuel: 100,
    );
    for (final backend in [
      _PenetrationBackend(peakMemoryBytes: budget.maximumMemoryBytes + 1),
      _PenetrationBackend(fuelConsumed: budget.maximumFuel + 1),
    ]) {
      final manager = WasmSandboxManager(backend: backend);
      final result = await manager.execute(
        _request('aggregate-metrics', budget: budget),
      );

      expect(result.status, SandboxJobStatus.failed);
      expect(result.reason, contains('resource boundary'));
      expect(backend.job.disposed, isTrue);
      await manager.dispose();
    }
  });
}

SandboxExecutionRequest _request(
  String moduleId, {
  SandboxExecutionBudget? budget,
}) => SandboxExecutionRequest(
  moduleId: moduleId,
  dataView: Uint8List.fromList(utf8.encode('{"rows":[]}')),
  budget: budget,
);

final class _PenetrationBackend implements SandboxRuntimeBackend {
  _PenetrationBackend({
    this.neverFinishes = false,
    this.peakMemoryBytes = 1024,
    this.fuelConsumed = 1,
  });

  final bool neverFinishes;
  final int peakMemoryBytes;
  final int fuelConsumed;
  bool started = false;
  late final _PenetrationJob job;

  @override
  Future<SandboxRuntimeCapability> capability() async =>
      const SandboxRuntimeCapability(
        kind: SandboxRuntimeKind.wasmtime,
        available: true,
        contractVersion: 1,
        backend: 'penetration-fixture',
        reason: '',
      );

  @override
  Future<SandboxRuntimeJob> start({
    required TrustedSandboxModule module,
    required Uint8List input,
    required SandboxExecutionBudget budget,
  }) async {
    started = true;
    return job = _PenetrationJob(
      neverFinishes: neverFinishes,
      peakMemoryBytes: peakMemoryBytes,
      fuelConsumed: fuelConsumed,
    );
  }
}

final class _PenetrationJob implements SandboxRuntimeJob {
  _PenetrationJob({
    required this.neverFinishes,
    required this.peakMemoryBytes,
    required this.fuelConsumed,
  });

  final bool neverFinishes;
  final int peakMemoryBytes;
  final int fuelConsumed;
  bool cancelled = false;
  bool disposed = false;

  @override
  Future<SandboxBackendPoll> poll() async {
    if (neverFinishes) await Completer<SandboxBackendPoll>().future;
    return SandboxBackendPoll(
      finished: true,
      succeeded: true,
      output: Uint8List.fromList(utf8.encode('{"console":"blocked"}')),
      fuelConsumed: fuelConsumed,
      peakMemoryBytes: peakMemoryBytes,
    );
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async => disposed = true;
}

Uint8List _importModule(String module, String name) => Uint8List.fromList([
  0,
  97,
  115,
  109,
  1,
  0,
  0,
  0,
  1,
  4,
  1,
  96,
  0,
  0,
  2,
  utf8.encode(module).length + utf8.encode(name).length + 5,
  1,
  utf8.encode(module).length,
  ...utf8.encode(module),
  utf8.encode(name).length,
  ...utf8.encode(name),
  0,
  0,
]);
