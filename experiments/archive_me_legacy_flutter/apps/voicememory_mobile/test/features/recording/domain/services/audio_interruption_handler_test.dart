import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/recording/domain/services/audio_interruption_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioInterruptionHandler', () {
    late _FakeRecordingOrchestrator orchestrator;
    late StreamController<InterruptionReason> interruptionEvents;
    late AudioInterruptionHandler handler;

    setUp(() {
      orchestrator = _FakeRecordingOrchestrator();
      interruptionEvents = StreamController<InterruptionReason>();
      handler = AudioInterruptionHandler(
        orchestrator: orchestrator,
        interruptionEvents: interruptionEvents.stream,
      );
    });

    tearDown(() async {
      handler.stopListening();
      await interruptionEvents.close();
    });

    testWidgets('saves once when inactive is followed by paused', (
      tester,
    ) async {
      handler.startListening();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(orchestrator.reasons, [InterruptionReason.appBackgrounded]);
    });

    testWidgets('handles another interruption after the app resumes', (
      tester,
    ) async {
      handler.startListening();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(orchestrator.reasons, [
        InterruptionReason.appBackgrounded,
        InterruptionReason.appBackgrounded,
      ]);
    });

    testWidgets('does nothing when no recording is active', (tester) async {
      orchestrator.isRecording = false;
      handler.startListening();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(orchestrator.reasons, isEmpty);
    });

    testWidgets('stops observing lifecycle changes', (tester) async {
      handler.startListening();
      handler.stopListening();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(orchestrator.reasons, isEmpty);
    });

    test('forwards native interruption reasons', () async {
      handler.startListening();

      interruptionEvents.add(InterruptionReason.phoneCallOrSystem);
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.reasons, [InterruptionReason.phoneCallOrSystem]);
    });

    test('coalesces interruptions while a draft save is in flight', () async {
      orchestrator.blockCompletion = true;
      handler.startListening();

      interruptionEvents
        ..add(InterruptionReason.phoneCallOrSystem)
        ..add(InterruptionReason.routeChange);
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.reasons, [InterruptionReason.phoneCallOrSystem]);

      orchestrator.completePendingSave();
    });
  });
}

final class _FakeRecordingOrchestrator implements AudioRecordingOrchestrator {
  @override
  bool isRecording = true;

  bool blockCompletion = false;
  final List<InterruptionReason> reasons = [];
  Completer<void>? _pendingSave;

  @override
  Future<void> pauseOrSaveDraftOnInterruption(InterruptionReason reason) async {
    reasons.add(reason);
    if (!blockCompletion) return;

    _pendingSave = Completer<void>();
    await _pendingSave!.future;
  }

  void completePendingSave() {
    _pendingSave?.complete();
    _pendingSave = null;
  }
}
