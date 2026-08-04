import 'dart:async';
import 'dart:typed_data';

import 'sandbox_audit_store.dart';
import 'sandbox_data_connector.dart';
import 'sandbox_models.dart';
import 'wasm_sandbox_manager.dart';

final class SandboxEnclaveSnapshot {
  const SandboxEnclaveSnapshot({
    required this.capabilities,
    required this.running,
    required this.audits,
    this.latest,
  });

  final List<SandboxRuntimeCapability> capabilities;
  final bool running;
  final List<SandboxAuditRecord> audits;
  final SandboxExecutionResult? latest;
}

final class SandboxEnclaveService {
  SandboxEnclaveService({
    required this.manager,
    required this.connector,
    required this.auditStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WasmSandboxManager manager;
  final SandboxDataConnector connector;
  final SandboxAuditStore auditStore;
  final DateTime Function() _clock;
  final StreamController<SandboxEnclaveSnapshot> _changes =
      StreamController.broadcast();
  SandboxEnclaveSnapshot _snapshot = const SandboxEnclaveSnapshot(
    capabilities: [],
    running: false,
    audits: [],
  );

  Stream<SandboxEnclaveSnapshot> get changes => _changes.stream;
  SandboxEnclaveSnapshot get current => _snapshot;

  Future<void> initialize() async {
    _snapshot = SandboxEnclaveSnapshot(
      capabilities: await manager.capabilities(),
      running: false,
      audits: await auditStore.read(),
    );
    _changes.add(_snapshot);
  }

  Future<SandboxExecutionResult> run({
    required String moduleId,
    required SandboxDataViewRequest dataRequest,
    Map<String, Object?> parameters = const {},
  }) async {
    final module = manager.registry.find(moduleId);
    if (module == null ||
        !module.manifest.dataGrants.contains(dataRequest.grant)) {
      return SandboxExecutionResult(
        status: SandboxJobStatus.failed,
        moduleId: moduleId,
        console: '',
        elapsed: Duration.zero,
        peakMemoryBytes: 0,
        fuelConsumed: 0,
        reason: 'The requested data grant is not declared by this module.',
      );
    }
    _set(running: true);
    Uint8List? view;
    try {
      view = await connector.createView(dataRequest);
      final result = await manager.execute(
        SandboxExecutionRequest(
          moduleId: moduleId,
          dataView: view,
          parameters: parameters,
        ),
      );
      final record = SandboxAuditRecord(
        id: '$moduleId:${_clock().toUtc().microsecondsSinceEpoch}',
        moduleId: moduleId,
        status: result.status,
        occurredAt: _clock(),
        elapsedMicroseconds: result.elapsed.inMicroseconds,
        peakMemoryBytes: result.peakMemoryBytes,
        fuelConsumed: result.fuelConsumed,
        grants: [dataRequest.grant],
        reason: result.reason,
      );
      await auditStore.append(record);
      _snapshot = SandboxEnclaveSnapshot(
        capabilities: _snapshot.capabilities,
        running: false,
        audits: [
          ..._snapshot.audits,
          record,
        ].skip((_snapshot.audits.length + 1 - 100).clamp(0, 100)).toList(),
        latest: result,
      );
      _changes.add(_snapshot);
      return result;
    } finally {
      view?.fillRange(0, view.length, 0);
      if (_snapshot.running) _set(running: false);
    }
  }

  Future<void> cancel() => manager.cancel();

  void _set({required bool running}) {
    _snapshot = SandboxEnclaveSnapshot(
      capabilities: _snapshot.capabilities,
      running: running,
      audits: _snapshot.audits,
      latest: _snapshot.latest,
    );
    _changes.add(_snapshot);
  }

  Future<void> clear() async {
    await auditStore.clear();
    _snapshot = SandboxEnclaveSnapshot(
      capabilities: _snapshot.capabilities,
      running: false,
      audits: const [],
    );
    _changes.add(_snapshot);
  }

  Future<void> dispose() async {
    await manager.dispose();
    await auditStore.dispose();
    await _changes.close();
  }
}
