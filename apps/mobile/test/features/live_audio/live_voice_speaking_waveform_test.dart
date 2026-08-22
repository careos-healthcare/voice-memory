import 'package:archiveme_mobile/widgets/live_voice/live_voice_speaking_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LiveVoiceSpeakingWaveform renders at different queue depths', (
    tester,
  ) async {
    for (final depth in [0, 1, 3]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveVoiceSpeakingWaveform(queueDepth: depth)),
        ),
      );
      expect(find.byType(LiveVoiceSpeakingWaveform), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
}