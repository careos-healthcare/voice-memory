import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/widgets/audio_visualizer.dart';

void main() {
  testWidgets(
    'renders and interpolates decibel samples without rebuilding UI',
    (tester) async {
      final decibels = StreamController<double>.broadcast();
      addTearDown(decibels.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AudioVisualizer(decibels: decibels.stream)),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AudioVisualizer),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Live microphone level'), findsOneWidget);

      decibels
        ..add(-48)
        ..add(-12);
      await tester.pump(const Duration(milliseconds: 34));

      expect(tester.takeException(), isNull);
      expect(find.byType(AudioVisualizer), findsOneWidget);
    },
  );
}
