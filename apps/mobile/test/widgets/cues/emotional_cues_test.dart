import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:archiveme_mobile/widgets/cues/emotional_cues.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hesitation and emotional-weight cues have no border', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HesitationSignalCue(
                label: 'Before speech',
                line: 'A pause, then the line.',
              ),
              EmotionalWeightCue(
                label: 'Fresh',
                line: 'This still carries weight.',
                state: EvidenceWeightState.fresh,
              ),
              EmotionalWeightCue(
                label: 'Older',
                line: 'This has gone quiet.',
                state: EvidenceWeightState.oldSignal,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('A pause, then the line.'), findsOneWidget);
    expect(find.text('This still carries weight.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HesitationSignalCue),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(EmotionalWeightCue),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );

    final fresh = tester.widget<Text>(find.text('Fresh'));
    final older = tester.widget<Text>(find.text('Older'));
    expect(fresh.style?.color?.a, greaterThan(older.style?.color?.a ?? 0));
  });
}
