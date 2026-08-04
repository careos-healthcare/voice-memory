import 'dart:collection';
import 'dart:typed_data';

enum SandboxRuntimeKind { wasmtime, pyodide, javascript }

enum SandboxDataGrant { graphNodes, cognitiveMetrics }

enum SandboxJobStatus {
  validating,
  running,
  succeeded,
  failed,
  timedOut,
  cancelled,
  capabilityUnavailable,
}

enum SandboxArtifactKind { text, table, series }

final class SandboxRuntimeCapability {
  const SandboxRuntimeCapability({
    required this.kind,
    required this.available,
    required this.contractVersion,
    required this.backend,
    required this.reason,
  });

  const SandboxRuntimeCapability.unavailable(this.kind, this.reason)
    : available = false,
      contractVersion = 1,
      backend = 'unavailable';

  final SandboxRuntimeKind kind;
  final bool available;
  final int contractVersion;
  final String backend;
  final String reason;
}

final class SandboxExecutionBudget {
  const SandboxExecutionBudget({
    this.timeout = const Duration(seconds: 5),
    this.maximumMemoryBytes = 16 * 1024 * 1024,
    this.maximumFuel = 5 * 1000 * 1000,
    this.maximumInputBytes = 256 * 1024,
    this.maximumOutputBytes = 256 * 1024,
  });

  final Duration timeout;
  final int maximumMemoryBytes;
  final int maximumFuel;
  final int maximumInputBytes;
  final int maximumOutputBytes;

  void validate() {
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 30)) {
      throw const FormatException('Sandbox timeout is outside safe bounds.');
    }
    if (maximumMemoryBytes < 64 * 1024 ||
        maximumMemoryBytes > 64 * 1024 * 1024 ||
        maximumFuel < 1 ||
        maximumFuel > 50 * 1000 * 1000 ||
        maximumInputBytes < 1 ||
        maximumInputBytes > 1024 * 1024 ||
        maximumOutputBytes < 1 ||
        maximumOutputBytes > 1024 * 1024) {
      throw const FormatException('Sandbox resource budget is unsafe.');
    }
  }
}

final class SandboxModuleManifest {
  SandboxModuleManifest({
    required this.id,
    required this.version,
    required this.displayName,
    required this.sha256,
    required this.entrypoint,
    required Iterable<String> allowedImports,
    required Iterable<SandboxDataGrant> dataGrants,
    this.budget = const SandboxExecutionBudget(),
  }) : allowedImports = Set.unmodifiable(allowedImports),
       dataGrants = Set.unmodifiable(dataGrants) {
    if (id.isEmpty ||
        version < 1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        !RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(entrypoint)) {
      throw const FormatException('Sandbox module manifest is invalid.');
    }
    budget.validate();
    if (allowedImports.any(
      (value) =>
          value.startsWith('wasi') ||
          value.contains('network') ||
          value.contains('filesystem') ||
          value.contains('environment') ||
          value.contains('clock') ||
          value.contains('process'),
    )) {
      throw const FormatException(
        'Sandbox manifest requests ambient authority.',
      );
    }
  }

  final String id;
  final int version;
  final String displayName;
  final String sha256;
  final String entrypoint;
  final Set<String> allowedImports;
  final Set<SandboxDataGrant> dataGrants;
  final SandboxExecutionBudget budget;
}

final class TrustedSandboxModule {
  TrustedSandboxModule({required this.manifest, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes);

  final SandboxModuleManifest manifest;
  final Uint8List bytes;
}

final class SandboxDataViewRequest {
  const SandboxDataViewRequest.graphNodes({
    required this.nodeIds,
    this.maximumRows = 100,
    this.maximumBytes = 256 * 1024,
  }) : grant = SandboxDataGrant.graphNodes,
       start = null,
       end = null;

  const SandboxDataViewRequest.cognitiveMetrics({
    this.start,
    this.end,
    this.maximumRows = 366,
    this.maximumBytes = 256 * 1024,
  }) : grant = SandboxDataGrant.cognitiveMetrics,
       nodeIds = const [];

  final SandboxDataGrant grant;
  final List<String> nodeIds;
  final DateTime? start;
  final DateTime? end;
  final int maximumRows;
  final int maximumBytes;
}

final class SandboxExecutionRequest {
  SandboxExecutionRequest({
    required this.moduleId,
    required this.dataView,
    Map<String, Object?> parameters = const {},
    this.budget,
  }) : parameters = UnmodifiableMapView(Map.of(parameters));

  final String moduleId;
  final Uint8List dataView;
  final Map<String, Object?> parameters;
  final SandboxExecutionBudget? budget;
}

final class SandboxArtifact {
  SandboxArtifact({
    required this.kind,
    required String title,
    required Iterable<Object?> values,
  }) : title = title.substring(0, title.length.clamp(0, 120).toInt()),
       values = List.unmodifiable(values.take(1000));

  final SandboxArtifactKind kind;
  final String title;
  final List<Object?> values;
}

final class SandboxExecutionResult {
  SandboxExecutionResult({
    required this.status,
    required this.moduleId,
    required this.console,
    required this.elapsed,
    required this.peakMemoryBytes,
    required this.fuelConsumed,
    this.artifact,
    this.reason,
  });

  final SandboxJobStatus status;
  final String moduleId;
  final String console;
  final Duration elapsed;
  final int peakMemoryBytes;
  final int fuelConsumed;
  final SandboxArtifact? artifact;
  final String? reason;
}
