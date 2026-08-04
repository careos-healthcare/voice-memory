import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'sandbox_models.dart';
import 'sandbox_runtime_backend.dart';

final class SandboxPreflight {
  const SandboxPreflight({
    required this.trusted,
    required this.capability,
    required this.reason,
    this.manifest,
  });

  final bool trusted;
  final SandboxRuntimeCapability capability;
  final String reason;
  final SandboxModuleManifest? manifest;

  bool get canRun => trusted && capability.available;
}

final class TrustedSandboxRegistry {
  TrustedSandboxRegistry(Iterable<TrustedSandboxModule> modules)
    : _modules = Map.unmodifiable({
        for (final module in modules) module.manifest.id: module,
      });

  factory TrustedSandboxRegistry.bundled() =>
      TrustedSandboxRegistry([_bundledAggregateModule()]);

  final Map<String, TrustedSandboxModule> _modules;

  List<SandboxModuleManifest> get manifests =>
      List.unmodifiable(_modules.values.map((item) => item.manifest));

  TrustedSandboxModule? find(String id) => _modules[id];
}

final class WasmSandboxManager {
  WasmSandboxManager({
    SandboxRuntimeBackend? backend,
    TrustedSandboxRegistry? registry,
  }) : backend = backend ?? createPlatformSandboxRuntimeBackend(),
       registry = registry ?? TrustedSandboxRegistry.bundled();

  final SandboxRuntimeBackend backend;
  final TrustedSandboxRegistry registry;
  SandboxRuntimeJob? _activeJob;
  bool _disposed = false;
  bool _cancelRequested = false;

  Future<List<SandboxRuntimeCapability>> capabilities() async => [
    await backend.capability(),
    const SandboxRuntimeCapability.unavailable(
      SandboxRuntimeKind.pyodide,
      'Pyodide is not packaged; Python source execution is disabled.',
    ),
    const SandboxRuntimeCapability.unavailable(
      SandboxRuntimeKind.javascript,
      'An audited JavaScript runtime is not packaged.',
    ),
  ];

  Future<SandboxPreflight> preflight(String moduleId) async {
    final capability = await backend.capability();
    final module = registry.find(moduleId);
    if (module == null) {
      return SandboxPreflight(
        trusted: false,
        capability: capability,
        reason: 'The module is not in the bundled allowlist.',
      );
    }
    try {
      _validateModule(module);
    } on FormatException catch (error) {
      return SandboxPreflight(
        trusted: false,
        capability: capability,
        manifest: module.manifest,
        reason: error.message,
      );
    }
    return SandboxPreflight(
      trusted: true,
      capability: capability,
      manifest: module.manifest,
      reason: capability.available ? '' : capability.reason,
    );
  }

  Future<SandboxExecutionResult> execute(
    SandboxExecutionRequest request,
  ) async {
    if (_disposed) throw StateError('Sandbox manager is disposed.');
    if (_activeJob != null) {
      throw StateError('A sandbox job is already active.');
    }
    final module = registry.find(request.moduleId);
    if (module == null) {
      return _result(
        request.moduleId,
        SandboxJobStatus.failed,
        reason: 'The module is not in the bundled allowlist.',
      );
    }
    try {
      _validateModule(module);
    } on FormatException catch (error) {
      return _result(
        request.moduleId,
        SandboxJobStatus.failed,
        reason: error.message,
      );
    }
    final capability = await backend.capability();
    if (!capability.available) {
      return _result(
        request.moduleId,
        SandboxJobStatus.capabilityUnavailable,
        reason: capability.reason,
      );
    }
    final budget = request.budget ?? module.manifest.budget;
    budget.validate();
    if (request.dataView.length > budget.maximumInputBytes) {
      return _result(
        request.moduleId,
        SandboxJobStatus.failed,
        reason: 'Sandbox input exceeds its declared budget.',
      );
    }
    final input = _encodeInput(request, budget);
    final watch = Stopwatch()..start();
    _cancelRequested = false;
    try {
      final job = await backend
          .start(module: module, input: input, budget: budget)
          .timeout(budget.timeout);
      _activeJob = job;
      while (true) {
        final remaining = budget.timeout - watch.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('Sandbox timed out.');
        }
        final poll = await job.poll().timeout(remaining);
        if (_cancelRequested) {
          return _result(
            request.moduleId,
            SandboxJobStatus.cancelled,
            elapsed: watch.elapsed,
            reason: 'Execution was cancelled.',
          );
        }
        if (!poll.finished) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          continue;
        }
        if (poll.peakMemoryBytes > budget.maximumMemoryBytes ||
            poll.fuelConsumed > budget.maximumFuel ||
            poll.output.length > budget.maximumOutputBytes) {
          return _result(
            request.moduleId,
            SandboxJobStatus.failed,
            elapsed: watch.elapsed,
            peakMemoryBytes: poll.peakMemoryBytes,
            fuelConsumed: poll.fuelConsumed,
            reason: 'The runtime exceeded a declared resource boundary.',
          );
        }
        if (!poll.succeeded) {
          return _result(
            request.moduleId,
            SandboxJobStatus.failed,
            elapsed: watch.elapsed,
            peakMemoryBytes: poll.peakMemoryBytes,
            fuelConsumed: poll.fuelConsumed,
            reason: poll.error ?? 'The isolated module failed.',
          );
        }
        return _decodeOutput(request.moduleId, poll, elapsed: watch.elapsed);
      }
    } on TimeoutException {
      await _activeJob?.cancel();
      return _result(
        request.moduleId,
        SandboxJobStatus.timedOut,
        elapsed: watch.elapsed,
        reason: 'Execution exceeded ${budget.timeout.inMilliseconds} ms.',
      );
    } on UnsupportedError catch (error) {
      return _result(
        request.moduleId,
        SandboxJobStatus.capabilityUnavailable,
        elapsed: watch.elapsed,
        reason: error.message?.toString(),
      );
    } on Object catch (error) {
      return _result(
        request.moduleId,
        SandboxJobStatus.failed,
        elapsed: watch.elapsed,
        reason: 'Sandbox backend failed: ${error.runtimeType}.',
      );
    } finally {
      input.fillRange(0, input.length, 0);
      await _activeJob?.dispose();
      _activeJob = null;
      _cancelRequested = false;
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    await _activeJob?.cancel();
  }

  Future<void> dispose() async {
    _disposed = true;
    await cancel();
    await _activeJob?.dispose();
    _activeJob = null;
  }

  void _validateModule(TrustedSandboxModule module) {
    if (module.bytes.length > 4 * 1024 * 1024) {
      throw const FormatException('Bundled module exceeds the size limit.');
    }
    final digest = sha256.convert(module.bytes).toString();
    if (digest != module.manifest.sha256) {
      throw const FormatException('Bundled module hash validation failed.');
    }
    final imports = _WasmImports.read(module.bytes);
    if (!module.manifest.allowedImports.containsAll(imports) ||
        imports.any((value) => !value.startsWith('enclave.'))) {
      throw const FormatException('Module requests an undeclared host import.');
    }
  }

  Uint8List _encodeInput(
    SandboxExecutionRequest request,
    SandboxExecutionBudget budget,
  ) {
    final decoded = jsonDecode(utf8.decode(request.dataView));
    final encoded = Uint8List.fromList(
      utf8.encode(
        jsonEncode({'data': decoded, 'parameters': request.parameters}),
      ),
    );
    if (encoded.length > budget.maximumInputBytes) {
      encoded.fillRange(0, encoded.length, 0);
      throw const FormatException('Combined sandbox input is too large.');
    }
    return encoded;
  }

  SandboxExecutionResult _decodeOutput(
    String moduleId,
    SandboxBackendPoll poll, {
    required Duration elapsed,
  }) {
    try {
      final decoded = jsonDecode(utf8.decode(poll.output));
      if (decoded is! Map) throw const FormatException();
      final console = (decoded['console'] as String? ?? '').substring(
        0,
        (decoded['console'] as String? ?? '').length.clamp(0, 8000).toInt(),
      );
      SandboxArtifact? artifact;
      final rawArtifact = decoded['artifact'];
      if (rawArtifact is Map) {
        artifact = SandboxArtifact(
          kind: SandboxArtifactKind.values.byName(
            rawArtifact['kind'] as String,
          ),
          title: rawArtifact['title'] as String? ?? 'Sandbox result',
          values: (rawArtifact['values'] as List? ?? const []).where(
            (value) =>
                value == null ||
                value is num ||
                value is bool ||
                value is String,
          ),
        );
      }
      return SandboxExecutionResult(
        status: SandboxJobStatus.succeeded,
        moduleId: moduleId,
        console: console,
        elapsed: elapsed,
        peakMemoryBytes: poll.peakMemoryBytes,
        fuelConsumed: poll.fuelConsumed,
        artifact: artifact,
      );
    } on Object {
      return _result(
        moduleId,
        SandboxJobStatus.failed,
        elapsed: elapsed,
        peakMemoryBytes: poll.peakMemoryBytes,
        fuelConsumed: poll.fuelConsumed,
        reason: 'The module returned an invalid output envelope.',
      );
    }
  }

  SandboxExecutionResult _result(
    String moduleId,
    SandboxJobStatus status, {
    Duration elapsed = Duration.zero,
    int peakMemoryBytes = 0,
    int fuelConsumed = 0,
    String? reason,
  }) => SandboxExecutionResult(
    status: status,
    moduleId: moduleId,
    console: '',
    elapsed: elapsed,
    peakMemoryBytes: peakMemoryBytes,
    fuelConsumed: fuelConsumed,
    reason: reason,
  );
}

TrustedSandboxModule _bundledAggregateModule() => TrustedSandboxModule(
  manifest: SandboxModuleManifest(
    id: 'aggregate-metrics',
    version: 1,
    displayName: 'Aggregate Metrics',
    sha256: 'c0be1d73f4ffd2e3680953b6038d0043c3c363126e5227d219602ddee1401e70',
    entrypoint: 'run',
    allowedImports: const {},
    dataGrants: const {SandboxDataGrant.cognitiveMetrics},
  ),
  bytes: Uint8List.fromList(const [
    0,
    97,
    115,
    109,
    1,
    0,
    0,
    0,
    1,
    5,
    1,
    96,
    0,
    1,
    127,
    3,
    2,
    1,
    0,
    7,
    7,
    1,
    3,
    114,
    117,
    110,
    0,
    0,
    10,
    6,
    1,
    4,
    0,
    65,
    0,
    11,
  ]),
);

final class _WasmImports {
  static Set<String> read(Uint8List bytes) {
    final reader = _WasmReader(bytes);
    if (!reader.consume(const [0, 97, 115, 109, 1, 0, 0, 0])) {
      throw const FormatException('Invalid WebAssembly module header.');
    }
    final imports = <String>{};
    while (!reader.done) {
      final section = reader.byte();
      final length = reader.varUint();
      final end = reader.offset + length;
      if (end > bytes.length) {
        throw const FormatException('Truncated Wasm section.');
      }
      if (section == 2) {
        final count = reader.varUint();
        for (var index = 0; index < count; index++) {
          final module = reader.string();
          final name = reader.string();
          imports.add('$module.$name');
          final kind = reader.byte();
          switch (kind) {
            case 0:
              reader.varUint();
            case 1:
              reader.byte();
              reader.limits();
            case 2:
              reader.limits();
            case 3:
              reader.byte();
              reader.byte();
            default:
              throw const FormatException('Unknown Wasm import kind.');
          }
        }
      }
      reader.offset = end;
    }
    return imports;
  }
}

final class _WasmReader {
  _WasmReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;
  bool get done => offset >= bytes.length;

  bool consume(List<int> expected) {
    if (bytes.length - offset < expected.length) return false;
    for (final value in expected) {
      if (byte() != value) return false;
    }
    return true;
  }

  int byte() {
    if (done) throw const FormatException('Unexpected end of Wasm module.');
    return bytes[offset++];
  }

  int varUint() {
    var value = 0;
    for (var shift = 0; shift < 35; shift += 7) {
      final next = byte();
      value |= (next & 0x7f) << shift;
      if (next & 0x80 == 0) return value;
    }
    throw const FormatException('Invalid Wasm integer encoding.');
  }

  String string() {
    final length = varUint();
    final end = offset + length;
    if (end > bytes.length) {
      throw const FormatException('Truncated Wasm string.');
    }
    final value = utf8.decode(
      bytes.sublist(offset, end),
      allowMalformed: false,
    );
    offset = end;
    return value;
  }

  void limits() {
    final flags = byte();
    varUint();
    if (flags & 1 == 1) varUint();
  }
}
