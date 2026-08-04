import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_models.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/sandbox_runtime_backend.dart';
import 'package:voicememory_mobile/features/sandbox_enclave/wasm_sandbox_manager.dart';

void main() {
  test('fails closed when the native runtime is unavailable', () async {
    final manager = WasmSandboxManager(
      backend: const UnavailableSandboxRuntimeBackend('not packaged'),
    );
    final result = await manager.execute(
      SandboxExecutionRequest(
        moduleId: 'aggregate-metrics',
        dataView: Uint8List.fromList(utf8.encode('{"rows":[]}')),
      ),
    );

    expect(result.status, SandboxJobStatus.capabilityUnavailable);
    expect(result.reason, contains('not packaged'));
    await manager.dispose();
  });

  test('cancels and disposes a job when its time budget expires', () async {
    final backend = _FakeBackend(neverFinishes: true);
    final manager = WasmSandboxManager(backend: backend);
    final result = await manager.execute(
      SandboxExecutionRequest(
        moduleId: 'aggregate-metrics',
        dataView: Uint8List.fromList(utf8.encode('{"rows":[]}')),
        budget: const SandboxExecutionBudget(
          timeout: Duration(milliseconds: 20),
        ),
      ),
    );

    expect(result.status, SandboxJobStatus.timedOut);
    expect(backend.job.cancelled, isTrue);
    expect(backend.job.disposed, isTrue);
    await manager.dispose();
  });

  test('rejects undeclared WASI imports before runtime dispatch', () async {
    final bytes = _wasiModule();
    final module = TrustedSandboxModule(
      manifest: SandboxModuleManifest(
        id: 'blocked',
        version: 1,
        displayName: 'Blocked',
        sha256: sha256.convert(bytes).toString(),
        entrypoint: 'run',
        allowedImports: const {},
        dataGrants: const {SandboxDataGrant.cognitiveMetrics},
      ),
      bytes: bytes,
    );
    final backend = _FakeBackend();
    final manager = WasmSandboxManager(
      backend: backend,
      registry: TrustedSandboxRegistry([module]),
    );

    final result = await manager.execute(
      SandboxExecutionRequest(
        moduleId: 'blocked',
        dataView: Uint8List.fromList(utf8.encode('{"rows":[]}')),
      ),
    );

    expect(result.status, SandboxJobStatus.failed);
    expect(result.reason, contains('undeclared host import'));
    expect(backend.started, isFalse);
    await manager.dispose();
  });

  test('enforces reported memory and output boundaries', () async {
    final backend = _FakeBackend(peakMemoryBytes: 80 * 1024 * 1024);
    final manager = WasmSandboxManager(backend: backend);
    final result = await manager.execute(
      SandboxExecutionRequest(
        moduleId: 'aggregate-metrics',
        dataView: Uint8List.fromList(utf8.encode('{"rows":[]}')),
      ),
    );

    expect(result.status, SandboxJobStatus.failed);
    expect(result.reason, contains('resource boundary'));
    await manager.dispose();
  });

  test('reports explicit cancellation and disposes the job', () async {
    final backend = _FakeBackend(pollDelay: const Duration(milliseconds: 30));
    final manager = WasmSandboxManager(backend: backend);
    final pending = manager.execute(
      SandboxExecutionRequest(
        moduleId: 'aggregate-metrics',
        dataView: Uint8List.fromList(utf8.encode('{"rows":[]}')),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await manager.cancel();
    final result = await pending;

    expect(result.status, SandboxJobStatus.cancelled);
    expect(backend.job.disposed, isTrue);
    await manager.dispose();
  });
}

final class _FakeBackend implements SandboxRuntimeBackend {
  _FakeBackend({
    this.neverFinishes = false,
    this.peakMemoryBytes = 1024,
    this.pollDelay = Duration.zero,
  });

  final bool neverFinishes;
  final int peakMemoryBytes;
  final Duration pollDelay;
  late final _FakeJob job;
  bool started = false;

  @override
  Future<SandboxRuntimeCapability> capability() async =>
      const SandboxRuntimeCapability(
        kind: SandboxRuntimeKind.wasmtime,
        available: true,
        contractVersion: 1,
        backend: 'fake-wasmtime',
        reason: '',
      );

  @override
  Future<SandboxRuntimeJob> start({
    required TrustedSandboxModule module,
    required Uint8List input,
    required SandboxExecutionBudget budget,
  }) async {
    started = true;
    return job = _FakeJob(
      neverFinishes: neverFinishes,
      peakMemoryBytes: peakMemoryBytes,
      pollDelay: pollDelay,
    );
  }
}

final class _FakeJob implements SandboxRuntimeJob {
  _FakeJob({
    required this.neverFinishes,
    required this.peakMemoryBytes,
    required this.pollDelay,
  });

  final bool neverFinishes;
  final int peakMemoryBytes;
  final Duration pollDelay;
  bool cancelled = false;
  bool disposed = false;

  @override
  Future<SandboxBackendPoll> poll() async {
    if (neverFinishes) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (pollDelay > Duration.zero) {
      await Future<void>.delayed(pollDelay);
    }
    return SandboxBackendPoll(
      finished: !neverFinishes,
      succeeded: true,
      output: Uint8List.fromList(
        utf8.encode(
          '{"console":"isolated ok","artifact":'
          '{"kind":"series","title":"Trend","values":[1,2,3]}}',
        ),
      ),
      fuelConsumed: 100,
      peakMemoryBytes: peakMemoryBytes,
    );
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async => disposed = true;
}

Uint8List _wasiModule() => Uint8List.fromList([
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
  35,
  1,
  22,
  ...utf8.encode('wasi_snapshot_preview1'),
  8,
  ...utf8.encode('fd_write'),
  0,
  0,
]);
