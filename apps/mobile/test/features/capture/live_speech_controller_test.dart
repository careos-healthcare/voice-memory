import 'package:archiveme_mobile/features/capture/controllers/live_speech_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSpeech extends LiveSpeechEngine {
  void Function(String words)? onPartial;
  void Function(double level)? onLevel;
  var started = false;

  @override
  Future<void> start({
    required void Function(String words) onPartial,
    required void Function(double level) onLevel,
  }) async {
    started = true;
    this.onPartial = onPartial;
    this.onLevel = onLevel;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  test('startListening moves from idle to listening', () async {
    final speech = _FakeSpeech();
    final controller = LiveSpeechController(engine: speech);
    expect(controller.state, RecordingState.idle);
    await controller.startListening();
    expect(speech.started, isTrue);
    expect(controller.state, RecordingState.listening);
    controller.dispose();
  });

  test('a partial transcript notifies listeners', () async {
    final speech = _FakeSpeech();
    final controller = LiveSpeechController(engine: speech);
    var notices = 0;
    controller.addListener(() => notices++);
    await controller.startListening();
    final before = notices;
    speech.onPartial!('the river');
    expect(controller.transcript, 'the river');
    expect(notices, greaterThan(before));
    controller.dispose();
  });

  test('quiet audio for 2500ms becomes silenceDetected', () async {
    final speech = _FakeSpeech();
    final controller = LiveSpeechController(
      engine: speech,
      silenceWindow: const Duration(milliseconds: 2500),
    );
    await controller.startListening();
    speech.onLevel!(0);
    await Future<void>.delayed(const Duration(milliseconds: 2490));
    expect(controller.state, RecordingState.listening);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state, RecordingState.silenceDetected);
    controller.dispose();
  });
}
