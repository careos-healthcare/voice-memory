import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';

import 'neural_dataset_builder.dart';
import 'neural_dataset_models.dart';

typedef LoRATrainingPromoter =
    Future<void> Function({
      required File safetensors,
      required File ggufAdapter,
      required LoRATrainingConfiguration configuration,
      required NativeLoRATrainingProgress progress,
    });

enum NeuralThermalState { nominal, fair, serious, critical, unavailable }

enum LoRATrainingStatus {
  idle,
  unsupported,
  preparing,
  training,
  pausedByHardware,
  pausedByUser,
  completed,
  cancelled,
  failed,
}

final class NeuralHardwareState {
  const NeuralHardwareState({
    required this.batteryPercent,
    required this.isCharging,
    required this.thermalState,
  });

  final int batteryPercent;
  final bool isCharging;
  final NeuralThermalState thermalState;

  bool get allowsTraining =>
      isCharging &&
      batteryPercent >= LoRAAdapterTrainer.minimumBatteryPercent &&
      thermalState != NeuralThermalState.serious &&
      thermalState != NeuralThermalState.critical;
}

abstract interface class NeuralHardwareProbe {
  Future<NeuralHardwareState> current();
}

final class PlatformNeuralHardwareProbe implements NeuralHardwareProbe {
  PlatformNeuralHardwareProbe({Battery? battery, MethodChannel? channel})
    : _battery = battery ?? Battery(),
      _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'archive_me/neural_hardware';

  final Battery _battery;
  final MethodChannel _channel;

  @override
  Future<NeuralHardwareState> current() async {
    final state = await _battery.batteryState;
    String? thermal;
    try {
      thermal = await _channel.invokeMethod<String>('thermalState');
    } on MissingPluginException {
      thermal = null;
    } on PlatformException {
      thermal = null;
    }
    return NeuralHardwareState(
      batteryPercent: await _battery.batteryLevel,
      isCharging: state == BatteryState.charging || state == BatteryState.full,
      thermalState: switch (thermal) {
        'nominal' => NeuralThermalState.nominal,
        'fair' => NeuralThermalState.fair,
        'serious' => NeuralThermalState.serious,
        'critical' => NeuralThermalState.critical,
        _ => NeuralThermalState.unavailable,
      },
    );
  }
}

final class LoRATrainerCapability {
  const LoRATrainerCapability({
    required this.available,
    required this.backend,
    required this.reason,
    this.abiVersion = 0,
  });

  const LoRATrainerCapability.unsupported([
    this.reason = 'No on-device LoRA trainer binary is installed.',
  ]) : available = false,
       backend = 'unsupported',
       abiVersion = 0;

  final bool available;
  final String backend;
  final String reason;
  final int abiVersion;
}

final class LoRATrainingConfiguration {
  const LoRATrainingConfiguration({
    required this.baseModelPath,
    required this.baseModelSha256,
    required this.outputDirectory,
    this.epochs = 3,
    this.rank = 8,
    this.learningRate = .0002,
    this.targetModules = const ['q_proj', 'v_proj'],
  });

  final String baseModelPath;
  final String baseModelSha256;
  final Directory outputDirectory;
  final int epochs;
  final int rank;
  final double learningRate;
  final List<String> targetModules;
}

final class NativeLoRATrainingProgress {
  const NativeLoRATrainingProgress({
    required this.epoch,
    required this.totalEpochs,
    required this.tokensProcessed,
    required this.loss,
    required this.finished,
    this.error,
    this.safetensorsPath,
    this.ggufAdapterPath,
  });

  final int epoch;
  final int totalEpochs;
  final int tokensProcessed;
  final double loss;
  final bool finished;
  final String? error;
  final String? safetensorsPath;
  final String? ggufAdapterPath;
}

abstract interface class NativeLoRATrainingBackend {
  Future<LoRATrainerCapability> capability();

  Future<String> start({
    required String datasetPath,
    required LoRATrainingConfiguration configuration,
  });

  Future<NativeLoRATrainingProgress> poll(String jobId);
  Future<void> pause(String jobId);
  Future<void> resume(String jobId);
  Future<void> cancel(String jobId);
}

final class UnsupportedNativeLoRATrainingBackend
    implements NativeLoRATrainingBackend {
  const UnsupportedNativeLoRATrainingBackend();

  @override
  Future<LoRATrainerCapability> capability() async =>
      const LoRATrainerCapability.unsupported();

  Never _unsupported() =>
      throw UnsupportedError('No native LoRA training backend is installed.');

  @override
  Future<String> start({
    required String datasetPath,
    required LoRATrainingConfiguration configuration,
  }) async => _unsupported();

  @override
  Future<NativeLoRATrainingProgress> poll(String jobId) async => _unsupported();

  @override
  Future<void> pause(String jobId) async => _unsupported();

  @override
  Future<void> resume(String jobId) async => _unsupported();

  @override
  Future<void> cancel(String jobId) async => _unsupported();
}

final class LoRATrainingState {
  const LoRATrainingState({
    this.status = LoRATrainingStatus.idle,
    this.epoch = 0,
    this.totalEpochs = 0,
    this.tokensProcessed = 0,
    this.lossHistory = const [],
    this.message = '',
    this.safetensorsPath,
    this.ggufAdapterPath,
  });

  final LoRATrainingStatus status;
  final int epoch;
  final int totalEpochs;
  final int tokensProcessed;
  final List<double> lossHistory;
  final String message;
  final String? safetensorsPath;
  final String? ggufAdapterPath;

  double get progress =>
      totalEpochs <= 0 ? 0 : (epoch / totalEpochs).clamp(0, 1);
}

final class LoRAAdapterTrainer {
  LoRAAdapterTrainer({
    required this.datasetBuilder,
    NativeLoRATrainingBackend backend =
        const UnsupportedNativeLoRATrainingBackend(),
    NeuralHardwareProbe? hardwareProbe,
    this.pollInterval = const Duration(milliseconds: 500),
    this.promote,
    // ignore: prefer_initializing_formals
  }) : _backend = backend,
       _hardwareProbe = hardwareProbe ?? PlatformNeuralHardwareProbe();

  static const minimumBatteryPercent = 30;

  final NeuralDatasetBuilder datasetBuilder;
  final NativeLoRATrainingBackend _backend;
  final NeuralHardwareProbe _hardwareProbe;
  final Duration pollInterval;
  final LoRATrainingPromoter? promote;
  final StreamController<LoRATrainingState> _states =
      StreamController<LoRATrainingState>.broadcast();

  LoRATrainingState _state = const LoRATrainingState();
  String? _jobId;
  MaterializedNeuralDataset? _materialized;
  bool _stopRequested = false;
  bool _userPaused = false;

  LoRATrainingState get state => _state;
  Stream<LoRATrainingState> get states => _states.stream;

  Future<LoRATrainerCapability> capability() => _backend.capability();

  Future<void> start(LoRATrainingConfiguration configuration) async {
    if (_isActive) throw StateError('A training job is already active.');
    final capability = await _backend.capability();
    if (!capability.available) {
      _emit(
        LoRATrainingState(
          status: LoRATrainingStatus.unsupported,
          message: capability.reason,
        ),
      );
      return;
    }
    if (configuration.baseModelSha256.trim().isEmpty ||
        !await File(configuration.baseModelPath).exists()) {
      throw StateError('The installed base model fingerprint is unavailable.');
    }
    final hardware = await _hardwareProbe.current();
    if (!hardware.allowsTraining) {
      _emit(
        const LoRATrainingState(
          status: LoRATrainingStatus.pausedByHardware,
          message: 'Connect power, charge above 30%, and let the device cool.',
        ),
      );
      return;
    }

    _stopRequested = false;
    _userPaused = false;
    _emit(
      LoRATrainingState(
        status: LoRATrainingStatus.preparing,
        totalEpochs: configuration.epochs,
        message: 'Preparing encrypted local corpus…',
      ),
    );
    try {
      await configuration.outputDirectory.create(recursive: true);
      _materialized = await datasetBuilder.materialize();
      _jobId = await _backend.start(
        datasetPath: _materialized!.file.path,
        configuration: configuration,
      );
      _emit(
        LoRATrainingState(
          status: LoRATrainingStatus.training,
          totalEpochs: configuration.epochs,
          message: 'Training locally on this device.',
        ),
      );
      await _runMonitor(configuration);
    } on Object catch (error) {
      _emit(
        LoRATrainingState(
          status: LoRATrainingStatus.failed,
          totalEpochs: configuration.epochs,
          lossHistory: _state.lossHistory,
          message: error.toString(),
        ),
      );
      await _cleanup();
    }
  }

  Future<void> pause() async {
    final jobId = _jobId;
    if (jobId == null || _state.status != LoRATrainingStatus.training) return;
    _userPaused = true;
    await _backend.pause(jobId);
    _emit(_copyState(LoRATrainingStatus.pausedByUser, 'Training paused.'));
  }

  Future<void> resume() async {
    final jobId = _jobId;
    if (jobId == null ||
        (_state.status != LoRATrainingStatus.pausedByUser &&
            _state.status != LoRATrainingStatus.pausedByHardware)) {
      return;
    }
    final hardware = await _hardwareProbe.current();
    if (!hardware.allowsTraining) return;
    _userPaused = false;
    await _backend.resume(jobId);
    _emit(_copyState(LoRATrainingStatus.training, 'Training resumed.'));
  }

  Future<void> cancel() async {
    _stopRequested = true;
    final jobId = _jobId;
    if (jobId != null) await _backend.cancel(jobId);
    _emit(_copyState(LoRATrainingStatus.cancelled, 'Training cancelled.'));
    await _cleanup();
  }

  Future<void> _runMonitor(LoRATrainingConfiguration configuration) async {
    while (!_stopRequested && _jobId != null) {
      await Future<void>.delayed(pollInterval);
      if (_stopRequested || _jobId == null) break;
      final hardware = await _hardwareProbe.current();
      if (!hardware.allowsTraining &&
          _state.status == LoRATrainingStatus.training) {
        await _backend.pause(_jobId!);
        _emit(
          _copyState(
            LoRATrainingStatus.pausedByHardware,
            'Training paused to protect battery and thermals.',
          ),
        );
        continue;
      }
      if (hardware.allowsTraining &&
          _state.status == LoRATrainingStatus.pausedByHardware &&
          !_userPaused) {
        await _backend.resume(_jobId!);
        _emit(_copyState(LoRATrainingStatus.training, 'Hardware is safe.'));
      }
      if (_state.status != LoRATrainingStatus.training) continue;
      final progress = await _backend.poll(_jobId!);
      final progressError = progress.error;
      if (progressError != null) {
        throw StateError(progressError);
      }
      final losses = [..._state.lossHistory, progress.loss];
      if (progress.finished) {
        if (progress.safetensorsPath == null ||
            progress.ggufAdapterPath == null ||
            !await File(progress.safetensorsPath!).exists() ||
            !await File(progress.ggufAdapterPath!).exists()) {
          throw StateError(
            'Native trainer did not produce both adapter formats.',
          );
        }
        await promote?.call(
          safetensors: File(progress.safetensorsPath!),
          ggufAdapter: File(progress.ggufAdapterPath!),
          configuration: configuration,
          progress: progress,
        );
        _emit(
          LoRATrainingState(
            status: LoRATrainingStatus.completed,
            epoch: progress.epoch,
            totalEpochs: progress.totalEpochs,
            tokensProcessed: progress.tokensProcessed,
            lossHistory: losses,
            message: 'Adapter training completed locally.',
            safetensorsPath: progress.safetensorsPath,
            ggufAdapterPath: progress.ggufAdapterPath,
          ),
        );
        await _cleanup();
        return;
      }
      _emit(
        LoRATrainingState(
          status: LoRATrainingStatus.training,
          epoch: progress.epoch,
          totalEpochs: progress.totalEpochs,
          tokensProcessed: progress.tokensProcessed,
          lossHistory: losses,
          message: 'Training locally on this device.',
        ),
      );
    }
  }

  bool get _isActive =>
      _state.status == LoRATrainingStatus.preparing ||
      _state.status == LoRATrainingStatus.training ||
      _state.status == LoRATrainingStatus.pausedByHardware ||
      _state.status == LoRATrainingStatus.pausedByUser;

  LoRATrainingState _copyState(LoRATrainingStatus status, String message) =>
      LoRATrainingState(
        status: status,
        epoch: _state.epoch,
        totalEpochs: _state.totalEpochs,
        tokensProcessed: _state.tokensProcessed,
        lossHistory: _state.lossHistory,
        message: message,
        safetensorsPath: _state.safetensorsPath,
        ggufAdapterPath: _state.ggufAdapterPath,
      );

  void _emit(LoRATrainingState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> _cleanup() async {
    await _materialized?.cleanup();
    _materialized = null;
    _jobId = null;
  }

  Future<void> dispose() async {
    if (_isActive) await cancel();
    await _states.close();
  }
}
