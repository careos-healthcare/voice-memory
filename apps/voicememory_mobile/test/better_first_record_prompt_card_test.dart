import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/widgets/record/better_first_record_prompt_card.dart';

void main() {
  testWidgets('shows title, body, examples and CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BetterFirstRecordPromptCard(onRecord: () {})),
      ),
    );

    expect(find.text('Start with one ordinary moment'), findsOneWidget);
    expect(
      find.textContaining('Say one moment that stayed with you'),
      findsOneWidget,
    );
    expect(find.text('I said yes too fast.'), findsOneWidget);
    expect(find.text('I kept thinking about the same thing.'), findsOneWidget);
    expect(find.text('I felt drained after a conversation.'), findsOneWidget);
    expect(find.text('Record that moment'), findsOneWidget);
  });

  testWidgets('tapping CTA fires onRecord', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BetterFirstRecordPromptCard(onRecord: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.text('Record that moment'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
