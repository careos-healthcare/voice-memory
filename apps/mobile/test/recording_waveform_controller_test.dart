import 'package:archiveme_mobile/widgets/record/recording_waveform_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordingWaveformController', () {
    test('normalizeDb maps silence and loud input into visual range', () {
      expect(
        RecordingWaveformController.normalizeDb(-60),
        RecordingWaveformController.idleLevel,
      );
      expect(
        RecordingWaveformController.normalizeDb(-10),
        greaterThan(0.5),
      );
      expect(RecordingWaveformController.normalizeDb(double.nan), 0.06);
    });

    test('pushNormalized shifts samples left and appends newest level', () {
      final controller = RecordingWaveformController(barCount: 4);
      controller.pushNormalized(0.2);
      controller.pushNormalized(0.5);
      controller.pushNormalized(0.9);

      expect(controller.levels, [0.06, 0.2, 0.5, 0.9]);
    });

    test('reset returns bars to idle level', () {
      final controller = RecordingWaveformController(barCount: 3);
      controller.pushNormalized(0.8);
      controller.reset();
      expect(controller.levels, [0.06, 0.06, 0.06]);
    });
  });
}