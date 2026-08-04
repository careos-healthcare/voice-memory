import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../services/analytics/ffi_safety_monitor.dart';
import 'lora_adapter_trainer.dart';

final class _NativeTrainerJob extends Opaque {}

final class _NativeTrainerConfiguration extends Struct {
  external Pointer<Utf8> baseModelPath;
  external Pointer<Utf8> baseModelSha256;
  external Pointer<Utf8> datasetJsonlPath;
  external Pointer<Utf8> outputDirectory;

  @Int32()
  external int epochs;

  @Int32()
  external int rank;

  @Float()
  external double learningRate;
}

final class _NativeTrainerProgress extends Struct {
  @Int32()
  external int epoch;

  @Int32()
  external int totalEpochs;

  @Int64()
  external int tokensProcessed;

  @Float()
  external double loss;

  @Int32()
  external int finished;

  external Pointer<Utf8> safetensorsPath;
  external Pointer<Utf8> ggufAdapterPath;
  external Pointer<Utf8> errorMessage;
}

typedef _AbiNative = Int32 Function();
typedef _AbiDart = int Function();
typedef _AvailableNative = Int32 Function();
typedef _AvailableDart = int Function();
typedef _NameNative = Pointer<Utf8> Function();
typedef _NameDart = Pointer<Utf8> Function();
typedef _StartNative =
    Int32 Function(
      Pointer<_NativeTrainerConfiguration>,
      Pointer<Pointer<_NativeTrainerJob>>,
    );
typedef _StartDart =
    int Function(
      Pointer<_NativeTrainerConfiguration>,
      Pointer<Pointer<_NativeTrainerJob>>,
    );
typedef _PollNative =
    Int32 Function(Pointer<_NativeTrainerJob>, Pointer<_NativeTrainerProgress>);
typedef _PollDart =
    int Function(Pointer<_NativeTrainerJob>, Pointer<_NativeTrainerProgress>);
typedef _JobOperationNative = Int32 Function(Pointer<_NativeTrainerJob>);
typedef _JobOperationDart = int Function(Pointer<_NativeTrainerJob>);
typedef _DisposeNative = Void Function(Pointer<_NativeTrainerJob>);
typedef _DisposeDart = void Function(Pointer<_NativeTrainerJob>);

NativeLoRATrainingBackend createPlatformLoRATrainingBackend() {
  try {
    return FfiNativeLoRATrainingBackend.open();
  } on Object {
    return const UnsupportedNativeLoRATrainingBackend();
  }
}

final class FfiNativeLoRATrainingBackend implements NativeLoRATrainingBackend {
  FfiNativeLoRATrainingBackend._(DynamicLibrary library)
    : _abi = library.lookupFunction<_AbiNative, _AbiDart>(
        'neural_trainer_abi_version',
      ),
      _available = library.lookupFunction<_AvailableNative, _AvailableDart>(
        'neural_trainer_is_available',
      ),
      _name = library.lookupFunction<_NameNative, _NameDart>(
        'neural_trainer_backend_name',
      ),
      _start = library.lookupFunction<_StartNative, _StartDart>(
        'neural_trainer_start',
      ),
      _poll = library.lookupFunction<_PollNative, _PollDart>(
        'neural_trainer_poll',
      ),
      _pause = library.lookupFunction<_JobOperationNative, _JobOperationDart>(
        'neural_trainer_pause',
      ),
      _resume = library.lookupFunction<_JobOperationNative, _JobOperationDart>(
        'neural_trainer_resume',
      ),
      _cancel = library.lookupFunction<_JobOperationNative, _JobOperationDart>(
        'neural_trainer_cancel',
      ),
      _dispose = library.lookupFunction<_DisposeNative, _DisposeDart>(
        'neural_trainer_dispose',
      );

  factory FfiNativeLoRATrainingBackend.open({DynamicLibrary? library}) {
    final backend = FfiNativeLoRATrainingBackend._(
      library ?? _openPlatformLibrary(),
    );
    if (backend._abi() != 1) {
      throw UnsupportedError('Unsupported neural trainer ABI.');
    }
    return backend;
  }

  final _AbiDart _abi;
  final _AvailableDart _available;
  final _NameDart _name;
  final _StartDart _start;
  final _PollDart _poll;
  final _JobOperationDart _pause;
  final _JobOperationDart _resume;
  final _JobOperationDart _cancel;
  final _DisposeDart _dispose;
  final Map<String, Pointer<_NativeTrainerJob>> _jobs = {};
  final Map<String, FFIResourceLease> _jobLeases = {};
  var _nextJobId = 1;

  @override
  Future<LoRATrainerCapability> capability() async {
    final name = _name();
    final available = _available() == 1;
    return LoRATrainerCapability(
      available: available,
      backend: name == nullptr ? 'native' : name.toDartString(),
      reason: available ? '' : 'The packaged trainer is unavailable.',
      abiVersion: _abi(),
    );
  }

  @override
  Future<String> start({
    required String datasetPath,
    required LoRATrainingConfiguration configuration,
  }) async {
    final native = calloc<_NativeTrainerConfiguration>();
    final output = calloc<Pointer<_NativeTrainerJob>>();
    native.ref
      ..baseModelPath = configuration.baseModelPath.toNativeUtf8()
      ..baseModelSha256 = configuration.baseModelSha256.toNativeUtf8()
      ..datasetJsonlPath = datasetPath.toNativeUtf8()
      ..outputDirectory = configuration.outputDirectory.path.toNativeUtf8()
      ..epochs = configuration.epochs
      ..rank = configuration.rank
      ..learningRate = configuration.learningRate;
    try {
      _requireOk(_start(native, output), 'start');
      if (output.value == nullptr) {
        throw StateError('Native trainer returned no job.');
      }
      final id = 'native-${_nextJobId++}';
      _jobs[id] = output.value;
      final lease = FFISafetyMonitor.installed?.acquire(
        FFIResourceKind.loraJob,
        owner: 'neural-trainer',
      );
      if (lease != null) _jobLeases[id] = lease;
      return id;
    } finally {
      calloc.free(native.ref.baseModelPath);
      calloc.free(native.ref.baseModelSha256);
      calloc.free(native.ref.datasetJsonlPath);
      calloc.free(native.ref.outputDirectory);
      calloc.free(native);
      calloc.free(output);
    }
  }

  @override
  Future<NativeLoRATrainingProgress> poll(String jobId) async {
    final job = _required(jobId);
    final output = calloc<_NativeTrainerProgress>();
    try {
      _requireOk(_poll(job, output), 'poll');
      final progress = NativeLoRATrainingProgress(
        epoch: output.ref.epoch,
        totalEpochs: output.ref.totalEpochs,
        tokensProcessed: output.ref.tokensProcessed,
        loss: output.ref.loss,
        finished: output.ref.finished == 1,
        safetensorsPath: _string(output.ref.safetensorsPath),
        ggufAdapterPath: _string(output.ref.ggufAdapterPath),
        error: _string(output.ref.errorMessage),
      );
      if (progress.finished || progress.error != null) _release(jobId);
      return progress;
    } finally {
      calloc.free(output);
    }
  }

  @override
  Future<void> pause(String jobId) async =>
      _requireOk(_pause(_required(jobId)), 'pause');

  @override
  Future<void> resume(String jobId) async =>
      _requireOk(_resume(_required(jobId)), 'resume');

  @override
  Future<void> cancel(String jobId) async {
    _requireOk(_cancel(_required(jobId)), 'cancel');
    _release(jobId);
  }

  Pointer<_NativeTrainerJob> _required(String id) {
    final job = _jobs[id];
    if (job == null) throw StateError('Native training job not found: $id');
    return job;
  }

  void _release(String id) {
    final job = _jobs.remove(id);
    try {
      if (job != null) _dispose(job);
    } finally {
      _jobLeases.remove(id)?.release();
    }
  }

  static String? _string(Pointer<Utf8> value) =>
      value == nullptr || value.toDartString().isEmpty
      ? null
      : value.toDartString();

  static void _requireOk(int status, String operation) {
    if (status != 0) {
      throw StateError('Native trainer $operation failed with status $status.');
    }
  }

  static DynamicLibrary _openPlatformLibrary() {
    final override = Platform.environment['ARCHIVEME_NEURAL_TRAINER_LIBRARY'];
    if (override != null && override.isNotEmpty) {
      return DynamicLibrary.open(override);
    }
    if (Platform.isIOS) return DynamicLibrary.process();
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libneural_trainer_mobile.so');
    }
    throw UnsupportedError('No mobile neural trainer library is available.');
  }
}
