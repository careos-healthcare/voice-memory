import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/neural_sculptor/lora_adapter_trainer.dart';
import 'package:voicememory_mobile/features/neural_sculptor/ui/neural_studio_sheet.dart';

void main() {
  testWidgets('progress dashboard animates state and hardware controls', (
    tester,
  ) async {
    var paused = 0;
    var resumed = 0;
    var cancelled = 0;
    var state = const LoRATrainingState(
      status: LoRATrainingStatus.training,
      epoch: 1,
      totalEpochs: 3,
      tokensProcessed: 120,
      lossHistory: [1.2, .8, .5],
    );

    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeuralTrainingStatusDashboard(
            capability: const LoRATrainerCapability(
              available: true,
              backend: 'test-native',
              reason: '',
              abiVersion: 1,
            ),
            state: state,
            canStart: false,
            onStart: () {},
            onPause: () => paused++,
            onResume: () => resumed++,
            onCancel: () => cancelled++,
          ),
        ),
      ),
    );

    await pump();
    expect(find.text('Epoch 1/3 · 120 tokens'), findsOneWidget);
    expect(find.byKey(const Key('neural-loss-curve')), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Cancel'));
    expect(paused, 1);
    expect(cancelled, 1);

    state = const LoRATrainingState(
      status: LoRATrainingStatus.pausedByHardware,
      epoch: 1,
      totalEpochs: 3,
      tokensProcessed: 120,
      lossHistory: [1.2, .8, .5],
    );
    await pump();
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    expect(resumed, 1);
  });

  testWidgets('unsupported capability disables training', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeuralTrainingStatusDashboard(
            capability: const LoRATrainerCapability.unsupported(),
            state: const LoRATrainingState(),
            canStart: false,
            onStart: () {},
            onPause: () {},
            onResume: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('No on-device LoRA trainer binary is installed.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('neural-start-training')))
          .onPressed,
      isNull,
    );
  });
}
