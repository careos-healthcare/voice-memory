import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/apex_profiler/apex_benchmark_runner.dart';
import 'package:voicememory_mobile/features/neural_sculptor/lora_adapter_trainer.dart';
import 'package:voicememory_mobile/services/analytics/ffi_safety_monitor.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('requires explicit owner authorization', () async {
    final root = await Directory.systemTemp.createTemp('apex-auth-test-');
    final runner = _runner(root);
    try {
      final result = await runner.run(ownerAuthorized: false);
      expect(result.status, ApexBenchmarkStatus.blocked);
      expect(result.report, isNull);
    } finally {
      await runner.dispose();
      await root.delete(recursive: true);
    }
  });

  test('uses isolated stores and writes an encrypted audit', () async {
    final root = await Directory.systemTemp.createTemp('apex-report-test-');
    final runner = _runner(root);
    try {
      final result = await runner.run(ownerAuthorized: true);

      expect(result.status, ApexBenchmarkStatus.completed);
      expect(result.scenarios, contains('graph_10000_us'));
      expect(result.scenarios, contains('muse_vector_sweep_us'));
      expect(result.scenarios, contains('crdt_merge_us'));
      expect(result.scenarios, contains('app_owned_native_lifecycle_us'));
      expect(
        result.skippedScenarios.values,
        everyElement(isNot(contains(root.path))),
      );
      expect(result.report, isNotNull);
      expect(await result.report!.exists(), isTrue);
      expect(await File('${result.report!.path}.tmp').exists(), isFalse);
      expect(await File('${result.report!.path}.previous').exists(), isFalse);
      expect(
        await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
          result.report!,
          'scenariosMicroseconds',
        ),
        isTrue,
      );
    } finally {
      await runner.dispose();
      await root.delete(recursive: true);
    }
  });

  test('fails closed when the benchmark deadline is exhausted', () async {
    final root = await Directory.systemTemp.createTemp('apex-deadline-test-');
    final runner = _runner(root, maximumDuration: Duration.zero);
    try {
      final result = await runner.run(ownerAuthorized: true);

      expect(result.status, ApexBenchmarkStatus.failed);
      expect(result.message, contains('deadline'));
      expect(result.report, isNull);
    } finally {
      await runner.dispose();
      await root.delete(recursive: true);
    }
  });

  test('records a reason when native lifecycle churn is unavailable', () async {
    final root = await Directory.systemTemp.createTemp('apex-skip-test-');
    final runner = _runner(root, includeMonitor: false);
    try {
      final result = await runner.run(ownerAuthorized: true);

      expect(result.status, ApexBenchmarkStatus.completed);
      expect(
        result.skippedScenarios['app_owned_native_lifecycle'],
        contains('unavailable'),
      );
    } finally {
      await runner.dispose();
      await root.delete(recursive: true);
    }
  });

  test('blocks foreground and thermal guard violations', () async {
    final root = await Directory.systemTemp.createTemp('apex-guards-test-');
    final background = _runner(root, foreground: false);
    final thermal = _runner(root, hardwareProbe: const _ThermalHardwareProbe());
    try {
      expect(
        (await background.run(ownerAuthorized: true)).status,
        ApexBenchmarkStatus.blocked,
      );
      expect(
        (await thermal.run(ownerAuthorized: true)).status,
        ApexBenchmarkStatus.blocked,
      );
    } finally {
      await background.dispose();
      await thermal.dispose();
      await root.delete(recursive: true);
    }
  });
}

ApexBenchmarkRunner _runner(
  Directory root, {
  Duration maximumDuration = const Duration(minutes: 2),
  bool includeMonitor = true,
  bool foreground = true,
  NeuralHardwareProbe hardwareProbe = const _HardwareProbe(),
}) => ApexBenchmarkRunner(
  hardwareProbe: hardwareProbe,
  auditWriter: ApexAuditWriter(
    directory: Directory('${root.path}/audits'),
    keyStore: InMemoryPrivateDataEncryptionKeyStore(),
  ),
  isForeground: () => foreground,
  ffiMonitor: includeMonitor
      ? FFISafetyMonitor(rssPressureThresholdBytes: 1 << 40)
      : null,
  maximumDuration: maximumDuration,
);

final class _HardwareProbe implements NeuralHardwareProbe {
  const _HardwareProbe();

  @override
  Future<NeuralHardwareState> current() async => const NeuralHardwareState(
    batteryPercent: 90,
    isCharging: true,
    thermalState: NeuralThermalState.nominal,
  );
}

final class _ThermalHardwareProbe implements NeuralHardwareProbe {
  const _ThermalHardwareProbe();

  @override
  Future<NeuralHardwareState> current() async => const NeuralHardwareState(
    batteryPercent: 90,
    isCharging: true,
    thermalState: NeuralThermalState.critical,
  );
}
