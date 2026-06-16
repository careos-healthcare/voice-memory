import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/routine/routine_anchor_model.dart';
import 'package:voicememory_mobile/widgets/routine/routine_anchor_chooser.dart';

void main() {
  testWidgets('shows the prompt and all anchor options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RoutineAnchorChooser(onSelected: (_) {})),
      ),
    );

    expect(find.text(RoutineAnchorChooser.title), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('After work'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('Before sleep'), findsOneWidget);
    expect(find.text('After a hard moment'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
  });

  testWidgets('tapping an option fires onSelected with that anchor', (
    tester,
  ) async {
    RoutineAnchor? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineAnchorChooser(onSelected: (a) => picked = a),
        ),
      ),
    );

    await tester.tap(find.text('Evening'));
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.type, RoutineAnchorType.evening);
    expect(picked!.displayLabel, 'Evening');
  });

  testWidgets('Custom reveals a field and returns the entered label', (
    tester,
  ) async {
    RoutineAnchor? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineAnchorChooser(onSelected: (a) => picked = a),
        ),
      ),
    );

    await tester.tap(find.text('Custom'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'On the commute');
    await tester.tap(find.text('Use this moment'));
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.type, RoutineAnchorType.custom);
    expect(picked!.displayLabel, 'On the commute');
  });
}
