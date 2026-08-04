import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../../services/analytics/ffi_safety_monitor.dart';
import '../../../services/security/native_boundary_fuzzer.dart';

final class _LlamaMobileSession extends Opaque {}

enum LlamaNativeStatus {
  ok(0),
  invalidArgument(1),
  modelLoadFailed(2),
  contextCreateFailed(3),
  contextLimit(4),
  tokenizeFailed(5),
  decodeFailed(6),
  cancelled(7),
  timedOut(8),
  outOfMemory(9),
  internalError(10);

  const LlamaNativeStatus(this.code);
  final int code;

  static LlamaNativeStatus fromCode(int code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return LlamaNativeStatus.internalError;
  }
}

final class LlamaNativeResult {
  const LlamaNativeResult(this.status, {this.output, this.error});

  final LlamaNativeStatus status;
  final String? output;
  final String? error;
}

abstract interface class LlamaNativeApi {
  int get abiVersion;

  Pointer<Void> createSession({
    required String modelPath,
    required int contextSize,
    required int threads,
    required int gpuLayers,
  });

  LlamaNativeResult complete(
    Pointer<Void> session, {
    required String prompt,
    required int maxTokens,
    required Duration timeout,
  });

  void cancel(Pointer<Void> session);
  void loadAdapter(
    Pointer<Void> session, {
    required String adapterPath,
    required double scale,
  });
  void unloadAdapter(Pointer<Void> session);
  void disposeSession(Pointer<Void> session);
}

typedef _CreateNative =
    Int32 Function(
      Pointer<Utf8>,
      Int32,
      Int32,
      Int32,
      Pointer<Pointer<_LlamaMobileSession>>,
    );
typedef _CreateDart =
    int Function(
      Pointer<Utf8>,
      int,
      int,
      int,
      Pointer<Pointer<_LlamaMobileSession>>,
    );
typedef _CompleteNative =
    Int32 Function(
      Pointer<_LlamaMobileSession>,
      Pointer<Utf8>,
      Int32,
      Int32,
      Pointer<Pointer<Char>>,
    );
typedef _CompleteDart =
    int Function(
      Pointer<_LlamaMobileSession>,
      Pointer<Utf8>,
      int,
      int,
      Pointer<Pointer<Char>>,
    );
typedef _CancelNative = Void Function(Pointer<_LlamaMobileSession>);
typedef _CancelDart = void Function(Pointer<_LlamaMobileSession>);
typedef _AdapterLoadNative =
    Int32 Function(Pointer<_LlamaMobileSession>, Pointer<Utf8>, Float);
typedef _AdapterLoadDart =
    int Function(Pointer<_LlamaMobileSession>, Pointer<Utf8>, double);
typedef _AdapterUnloadNative = Int32 Function(Pointer<_LlamaMobileSession>);
typedef _AdapterUnloadDart = int Function(Pointer<_LlamaMobileSession>);
typedef _LastErrorNative = Pointer<Char> Function(Pointer<_LlamaMobileSession>);
typedef _LastErrorDart = Pointer<Char> Function(Pointer<_LlamaMobileSession>);
typedef _OutputFreeNative = Void Function(Pointer<Char>);
typedef _OutputFreeDart = void Function(Pointer<Char>);
typedef _DisposeNative = Void Function(Pointer<_LlamaMobileSession>);
typedef _DisposeDart = void Function(Pointer<_LlamaMobileSession>);
typedef _AbiVersionNative = Int32 Function();
typedef _AbiVersionDart = int Function();

final class LlamaNativeBindings implements LlamaNativeApi {
  LlamaNativeBindings._(DynamicLibrary library)
    : _create = library.lookupFunction<_CreateNative, _CreateDart>(
        'llama_mobile_session_create',
      ),
      _complete = library.lookupFunction<_CompleteNative, _CompleteDart>(
        'llama_mobile_complete',
      ),
      _cancel = library.lookupFunction<_CancelNative, _CancelDart>(
        'llama_mobile_cancel',
      ),
      _adapterLoad = library
          .lookupFunction<_AdapterLoadNative, _AdapterLoadDart>(
            'llama_mobile_adapter_load',
          ),
      _adapterUnload = library
          .lookupFunction<_AdapterUnloadNative, _AdapterUnloadDart>(
            'llama_mobile_adapter_unload',
          ),
      _lastError = library.lookupFunction<_LastErrorNative, _LastErrorDart>(
        'llama_mobile_last_error',
      ),
      _outputFree = library.lookupFunction<_OutputFreeNative, _OutputFreeDart>(
        'llama_mobile_output_free',
      ),
      _dispose = library.lookupFunction<_DisposeNative, _DisposeDart>(
        'llama_mobile_session_dispose',
      ),
      _abiVersion = library.lookupFunction<_AbiVersionNative, _AbiVersionDart>(
        'llama_mobile_abi_version',
      );

  factory LlamaNativeBindings.open({DynamicLibrary? library}) {
    final resolved = library ?? _openPlatformLibrary();
    final bindings = LlamaNativeBindings._(resolved);
    if (bindings.abiVersion != 2) {
      throw UnsupportedError(
        'Unsupported llama_mobile ABI ${bindings.abiVersion}; expected 2.',
      );
    }
    return bindings;
  }

  final _CreateDart _create;
  final _CompleteDart _complete;
  final _CancelDart _cancel;
  final _AdapterLoadDart _adapterLoad;
  final _AdapterUnloadDart _adapterUnload;
  final _LastErrorDart _lastError;
  final _OutputFreeDart _outputFree;
  final _DisposeDart _dispose;
  final _AbiVersionDart _abiVersion;
  final Map<int, FFIResourceLease> _sessionLeases = {};
  final Set<int> _sessionAddresses = {};

  @override
  int get abiVersion => _abiVersion();

  @override
  Pointer<Void> createSession({
    required String modelPath,
    required int contextSize,
    required int threads,
    required int gpuLayers,
  }) {
    final pathBytes = utf8.encode(modelPath);
    NativeBoundaryContract.requireBoundedBytes(pathBytes.length, maximum: 4096);
    if (pathBytes.isEmpty ||
        contextSize < 256 ||
        contextSize > 8192 ||
        threads < 1 ||
        threads > 8 ||
        gpuLayers < -1 ||
        gpuLayers > 256) {
      throw const NativeBoundaryViolation(
        'Invalid llama.cpp session parameters.',
      );
    }
    final path = modelPath.toNativeUtf8();
    final output = calloc<Pointer<_LlamaMobileSession>>();
    try {
      final status = LlamaNativeStatus.fromCode(
        _create(path, contextSize, threads, gpuLayers, output),
      );
      if (status != LlamaNativeStatus.ok || output.value == nullptr) {
        throw LlamaNativeCallException(
          status,
          'Unable to create native llama session.',
        );
      }
      final session = output.value.cast<Void>();
      _sessionAddresses.add(session.address);
      final lease = FFISafetyMonitor.installed?.acquire(
        FFIResourceKind.llamaSession,
        owner: 'llama.cpp',
      );
      if (lease != null) _sessionLeases[session.address] = lease;
      return session;
    } finally {
      calloc.free(path);
      calloc.free(output);
    }
  }

  @override
  LlamaNativeResult complete(
    Pointer<Void> session, {
    required String prompt,
    required int maxTokens,
    required Duration timeout,
  }) {
    _requireSession(session);
    final promptBytes = utf8.encode(prompt);
    NativeBoundaryContract.requireBoundedBytes(
      promptBytes.length,
      maximum: 1024 * 1024,
    );
    if (promptBytes.isEmpty ||
        maxTokens < 1 ||
        maxTokens > 1024 ||
        timeout <= Duration.zero ||
        timeout > const Duration(minutes: 5)) {
      throw const NativeBoundaryViolation(
        'Invalid llama.cpp completion parameters.',
      );
    }
    final nativeSession = session.cast<_LlamaMobileSession>();
    final nativePrompt = prompt.toNativeUtf8();
    final output = calloc<Pointer<Char>>();
    try {
      final status = LlamaNativeStatus.fromCode(
        _complete(
          nativeSession,
          nativePrompt,
          maxTokens,
          timeout.inMilliseconds,
          output,
        ),
      );
      if (status != LlamaNativeStatus.ok) {
        final errorPointer = _lastError(nativeSession);
        return LlamaNativeResult(
          status,
          error: errorPointer == nullptr
              ? 'Native inference failed.'
              : errorPointer.cast<Utf8>().toDartString(),
        );
      }
      final pointer = output.value;
      if (pointer == nullptr) {
        return const LlamaNativeResult(
          LlamaNativeStatus.internalError,
          error: 'Native inference returned no output.',
        );
      }
      final outputLease = FFISafetyMonitor.installed?.acquire(
        FFIResourceKind.llamaOutput,
        owner: 'llama.cpp completion',
      );
      try {
        return LlamaNativeResult(
          status,
          output: pointer.cast<Utf8>().toDartString(),
        );
      } finally {
        _outputFree(pointer);
        outputLease?.release();
      }
    } finally {
      calloc.free(nativePrompt);
      calloc.free(output);
    }
  }

  @override
  void cancel(Pointer<Void> session) {
    _requireSession(session);
    _cancel(session.cast<_LlamaMobileSession>());
  }

  @override
  void loadAdapter(
    Pointer<Void> session, {
    required String adapterPath,
    required double scale,
  }) {
    _requireSession(session);
    final pathBytes = utf8.encode(adapterPath);
    NativeBoundaryContract.requireBoundedBytes(pathBytes.length, maximum: 4096);
    if (pathBytes.isEmpty || !scale.isFinite || scale < 0 || scale > 4) {
      throw const NativeBoundaryViolation(
        'Invalid llama.cpp adapter parameters.',
      );
    }
    final nativePath = adapterPath.toNativeUtf8();
    try {
      final nativeSession = session.cast<_LlamaMobileSession>();
      final status = LlamaNativeStatus.fromCode(
        _adapterLoad(nativeSession, nativePath, scale),
      );
      if (status != LlamaNativeStatus.ok) {
        final errorPointer = _lastError(nativeSession);
        throw LlamaNativeCallException(
          status,
          errorPointer == nullptr
              ? 'Unable to load LoRA adapter.'
              : errorPointer.cast<Utf8>().toDartString(),
        );
      }
    } finally {
      calloc.free(nativePath);
    }
  }

  @override
  void unloadAdapter(Pointer<Void> session) {
    _requireSession(session);
    final nativeSession = session.cast<_LlamaMobileSession>();
    final status = LlamaNativeStatus.fromCode(_adapterUnload(nativeSession));
    if (status != LlamaNativeStatus.ok) {
      final errorPointer = _lastError(nativeSession);
      throw LlamaNativeCallException(
        status,
        errorPointer == nullptr
            ? 'Unable to unload LoRA adapter.'
            : errorPointer.cast<Utf8>().toDartString(),
      );
    }
  }

  @override
  void disposeSession(Pointer<Void> session) {
    _requireSession(session);
    _dispose(session.cast<_LlamaMobileSession>());
    _sessionAddresses.remove(session.address);
    _sessionLeases.remove(session.address)?.release();
  }

  void _requireSession(Pointer<Void> session) {
    NativeBoundaryContract.requireOwnedPointer(
      session.address,
      ownedAddresses: _sessionAddresses,
    );
  }

  static DynamicLibrary _openPlatformLibrary() {
    final override = Platform.environment['ARCHIVEME_LLAMA_LIBRARY'];
    if (override != null && override.isNotEmpty) {
      return DynamicLibrary.open(override);
    }
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libllama_mobile.so');
    }
    throw UnsupportedError(
      'llama_mobile is available only on configured Android/iOS builds.',
    );
  }
}

final class LlamaNativeCallException implements Exception {
  const LlamaNativeCallException(this.status, this.message);

  final LlamaNativeStatus status;
  final String message;

  @override
  String toString() => 'LlamaNativeCallException(${status.name}): $message';
}
