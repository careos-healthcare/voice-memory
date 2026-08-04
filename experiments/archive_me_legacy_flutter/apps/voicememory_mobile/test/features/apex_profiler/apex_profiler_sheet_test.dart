import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/apex_profiler/apex_benchmark_runner.dart';
import 'package:voicememory_mobile/features/apex_profiler/apex_profiler_service.dart';
import 'package:voicememory_mobile/features/apex_profiler/ui/apex_profiler_sheet.dart';
import 'package:voicememory_mobile/features/neural_sculptor/lora_adapter_trainer.dart';
import 'package:voicememory_mobile/services/analytics/ffi_safety_monitor.dart';
import 'package:voicememory_mobile/services/analytics/frame_performance_tracker.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('renders telemetry and owner-authorized benchmark controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final root = Directory('${Directory.systemTemp.path}/apex-widget-test');
    final service = ApexProfilerService(
      ffiMonitor: FFISafetyMonitor(rssPressureThresholdBytes: 1 << 40),
      frameTracker: FramePerformanceTracker(),
      benchmarkRunner: ApexBenchmarkRunner(
        hardwareProbe: const _HardwareProbe(),
        auditWriter: ApexAuditWriter(
          directory: Directory('${root.path}/audits'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
        isForeground: () => true,
      ),
    );
    var authorizationRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ApexProfilerSheet(
              service: service,
              authorizeOwner: () async {
                authorizationRequests++;
                return false;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('apex-gauge-fps')), findsOneWidget);
    expect(find.byKey(const Key('apex-gauge-ram')), findsOneWidget);
    expect(find.byKey(const Key('apex-gauge-ffi')), findsOneWidget);
    expect(find.byKey(const Key('apex-gauge-native-guard')), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);

    await tester.tap(find.byKey(const Key('apex-assert-leaks')));
    await tester.pump();
    expect(find.text('No active app-owned resource leaks.'), findsOneWidget);

    expect(find.byKey(const Key('apex-run-benchmark')), findsOneWidget);
    await tester.tap(find.byKey(const Key('apex-run-benchmark')));
    await tester.pump();
    expect(authorizationRequests, 1);
    expect(find.text('Run isolated stress benchmark?'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    service.pause();
  });
}

final class _HardwareProbe implements NeuralHardwareProbe {
  const _HardwareProbe();

  @override
  Future<NeuralHardwareState> current() async => const NeuralHardwareState(
    batteryPercent: 90,
    isCharging: true,
    thermalState: NeuralThermalState.nominal,
  );
}
