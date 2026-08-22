import 'package:archiveme_mobile/widgets/record/recording_waveform.dart';
import 'package:archiveme_mobile/widgets/record/recording_waveform_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RebuildCounter extends StatelessWidget {
  const _RebuildCounter({required this.child});

  final Widget child;
  static int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount += 1;
    return child;
  }
}

void main() {
  testWidgets('RecordingWaveform repaints via CustomPaint without parent rebuilds', (
    tester,
  ) async {
    final controller = RecordingWaveformController(barCount: 12);
    _RebuildCounter.buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _RebuildCounter(
            child: RecordingWaveform(controller: controller),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(RecordingWaveform),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    final initialBuildCount = _RebuildCounter.buildCount;

    for (var i = 0; i < 8; i++) {
      controller.pushNormalized(0.2 + (i * 0.08));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(_RebuildCounter.buildCount, initialBuildCount);
  });
}