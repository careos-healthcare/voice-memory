import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../services/analytics/ffi_safety_monitor.dart';
import 'sandbox_models.dart';

final class SandboxBackendPoll {
  const SandboxBackendPoll({
    required this.finished,
    required this.succeeded,
    required this.output,
    required this.fuelConsumed,
    required this.peakMemoryBytes,
    this.error,
  });

  final bool finished;
  final bool succeeded;
  final Uint8List output;
  final int fuelConsumed;
  final int peakMemoryBytes;
  final String? error;
}

abstract interface class SandboxRuntimeJob {
  Future<SandboxBackendPoll> poll();
  Future<void> cancel();
  Future<void> dispose();
}

abstract interface class SandboxRuntimeBackend {
  Future<SandboxRuntimeCapability> capability();
  Future<SandboxRuntimeJob> start({
    required TrustedSandboxModule module,
    required Uint8List input,
    required SandboxExecutionBudget budget,
  });
}

final class UnavailableSandboxRuntimeBackend implements SandboxRuntimeBackend {
  const UnavailableSandboxRuntimeBackend([
    this.reason = 'The audited Wasmtime runtime is not packaged.',
  ]);

  final String reason;

  @override
  Future<SandboxRuntimeCapability> capability() async =>
      SandboxRuntimeCapability.unavailable(SandboxRuntimeKind.wasmtime, reason);

  @override
  Future<SandboxRuntimeJob> start({
    required TrustedSandboxModule module,
    required Uint8List input,
    required SandboxExecutionBudget budget,
  }) => Future.error(UnsupportedError(reason));
}

SandboxRuntimeBackend createPlatformSandboxRuntimeBackend() {
  try {
    return FfiSandboxRuntimeBackend.open();
  } on Object {
    return const UnavailableSandboxRuntimeBackend();
  }
}

final class _NativeWasmJob extends Opaque {}

final class _NativeWasmLimits extends Struct {
  @Uint64()
  external int maximumFuel;

  @Uint64()
  external int maximumMemoryBytes;

  @Uint64()
  external int maximumOutputBytes;
}

final class _NativeWasmStatus extends Struct {
  @Int32()
  external int finished;

  @Int32()
  external int succeeded;

  @Uint64()
  external int fuelConsumed;

  @Uint64()
  external int peakMemoryBytes;

  external Pointer<Uint8> outputBytes;

  @Size()
  external int outputLength;

  external Pointer<Utf8> errorMessage;
}

typedef _IntNative = Int32 Function();
typedef _IntDart = int Function();
typedef _NameNative = Pointer<Utf8> Function();
typedef _NameDart = Pointer<Utf8> Function();
typedef _CreateNative =
    Int32 Function(
      Pointer<Uint8>,
      Size,
      Pointer<Utf8>,
      Pointer<Uint8>,
      Size,
      Pointer<_NativeWasmLimits>,
      Pointer<Pointer<_NativeWasmJob>>,
    );
typedef _CreateDart =
    int Function(
      Pointer<Uint8>,
      int,
      Pointer<Utf8>,
      Pointer<Uint8>,
      int,
      Pointer<_NativeWasmLimits>,
      Pointer<Pointer<_NativeWasmJob>>,
    );
typedef _PollNative =
    Int32 Function(Pointer<_NativeWasmJob>, Pointer<_NativeWasmStatus>);
typedef _PollDart =
    int Function(Pointer<_NativeWasmJob>, Pointer<_NativeWasmStatus>);
typedef _CancelNative = Int32 Function(Pointer<_NativeWasmJob>);
typedef _CancelDart = int Function(Pointer<_NativeWasmJob>);
typedef _DisposeNative = Void Function(Pointer<_NativeWasmJob>);
typedef _DisposeDart = void Function(Pointer<_NativeWasmJob>);

final class FfiSandboxRuntimeBackend implements SandboxRuntimeBackend {
  FfiSandboxRuntimeBackend._(DynamicLibrary library)
    : _abi = library.lookupFunction<_IntNative, _IntDart>(
        'archiveme_wasm_abi_version',
      ),
      _available = library.lookupFunction<_IntNative, _IntDart>(
        'archiveme_wasm_is_available',
      ),
      _name = library.lookupFunction<_NameNative, _NameDart>(
        'archiveme_wasm_backend_name',
      ),
      _create = library.lookupFunction<_CreateNative, _CreateDart>(
        'archiveme_wasm_job_create',
      ),
      _poll = library.lookupFunction<_PollNative, _PollDart>(
        'archiveme_wasm_job_poll',
      ),
      _cancel = library.lookupFunction<_CancelNative, _CancelDart>(
        'archiveme_wasm_job_cancel',
      ),
      _dispose = library.lookupFunction<_DisposeNative, _DisposeDart>(
        'archiveme_wasm_job_dispose',
      );

  factory FfiSandboxRuntimeBackend.open({DynamicLibrary? library}) {
    final backend = FfiSandboxRuntimeBackend._(
      library ?? _openPlatformLibrary(),
    );
    if (backend._abi() != 1) {
      throw UnsupportedError('Unsupported Wasm sandbox ABI.');
    }
    return backend;
  }

  final _IntDart _abi;
  final _IntDart _available;
  final _NameDart _name;
  final _CreateDart _create;
  final _PollDart _poll;
  final _CancelDart _cancel;
  final _DisposeDart _dispose;

  @override
  Future<SandboxRuntimeCapability> capability() async {
    final available = _available() == 1;
    final name = _name();
    return SandboxRuntimeCapability(
      kind: SandboxRuntimeKind.wasmtime,
      available: available,
      contractVersion: _abi(),
      backend: name == nullptr ? 'native' : name.toDartString(),
      reason: available ? '' : 'The packaged Wasmtime backend is unavailable.',
    );
  }

  @override
  Future<SandboxRuntimeJob> start({
    required TrustedSandboxModule module,
    required Uint8List input,
    required SandboxExecutionBudget budget,
  }) async {
    if (_available() != 1) {
      throw UnsupportedError('The packaged Wasmtime backend is unavailable.');
    }
    final moduleBytes = calloc<Uint8>(module.bytes.length);
    final inputBytes = calloc<Uint8>(input.length);
    final entrypoint = module.manifest.entrypoint.toNativeUtf8();
    final limits = calloc<_NativeWasmLimits>();
    final output = calloc<Pointer<_NativeWasmJob>>();
    moduleBytes.asTypedList(module.bytes.length).setAll(0, module.bytes);
    inputBytes.asTypedList(input.length).setAll(0, input);
    limits.ref
      ..maximumFuel = budget.maximumFuel
      ..maximumMemoryBytes = budget.maximumMemoryBytes
      ..maximumOutputBytes = budget.maximumOutputBytes;
    try {
      final status = _create(
        moduleBytes,
        module.bytes.length,
        entrypoint,
        inputBytes,
        input.length,
        limits,
        output,
      );
      if (status != 0 || output.value == nullptr) {
        throw StateError('Native Wasm job creation failed: $status.');
      }
      return _FfiSandboxRuntimeJob(
        output.value,
        _poll,
        _cancel,
        _dispose,
        FFISafetyMonitor.installed?.acquire(
          FFIResourceKind.sandboxSession,
          owner: 'wasm-sandbox-job',
          estimatedBytes: budget.maximumMemoryBytes,
        ),
      );
    } finally {
      moduleBytes
          .asTypedList(module.bytes.length)
          .fillRange(0, module.bytes.length, 0);
      inputBytes.asTypedList(input.length).fillRange(0, input.length, 0);
      calloc
        ..free(moduleBytes)
        ..free(inputBytes)
        ..free(entrypoint)
        ..free(limits)
        ..free(output);
    }
  }

  static DynamicLibrary _openPlatformLibrary() {
    // Security boundary: only process-linked or packaged library names are
    // accepted. Environment-selected paths would permit an arbitrary host
    // library to impersonate the audited sandbox ABI.
    if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process();
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libarchive_wasm_sandbox.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('archive_wasm_sandbox.dll');
    }
    throw UnsupportedError('No Wasm sandbox library for this platform.');
  }
}

final class _FfiSandboxRuntimeJob implements SandboxRuntimeJob {
  _FfiSandboxRuntimeJob(
    this._job,
    this._poll,
    this._cancel,
    this._dispose,
    this._lease,
  );

  Pointer<_NativeWasmJob> _job;
  final _PollDart _poll;
  final _CancelDart _cancel;
  final _DisposeDart _dispose;
  final FFIResourceLease? _lease;

  @override
  Future<SandboxBackendPoll> poll() async {
    if (_job == nullptr) throw StateError('Sandbox job is disposed.');
    final output = calloc<_NativeWasmStatus>();
    try {
      final status = _poll(_job, output);
      if (status != 0) throw StateError('Native Wasm poll failed: $status.');
      final length = output.ref.outputLength;
      final bytes = output.ref.outputBytes == nullptr || length == 0
          ? Uint8List(0)
          : Uint8List.fromList(output.ref.outputBytes.asTypedList(length));
      return SandboxBackendPoll(
        finished: output.ref.finished == 1,
        succeeded: output.ref.succeeded == 1,
        output: bytes,
        fuelConsumed: output.ref.fuelConsumed,
        peakMemoryBytes: output.ref.peakMemoryBytes,
        error: output.ref.errorMessage == nullptr
            ? null
            : output.ref.errorMessage.toDartString(),
      );
    } finally {
      calloc.free(output);
    }
  }

  @override
  Future<void> cancel() async {
    if (_job != nullptr) _cancel(_job);
  }

  @override
  Future<void> dispose() async {
    if (_job == nullptr) return;
    try {
      _dispose(_job);
    } finally {
      _job = nullptr;
      _lease?.release();
    }
  }
}
