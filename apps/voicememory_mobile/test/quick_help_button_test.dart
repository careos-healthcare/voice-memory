import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/widgets/quick_help/quick_help_button.dart';

void main() {
  testWidgets('shows a quiet Need help? pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickHelpButton(onStartRecording: () async {}),
        ),
      ),
    );
    expect(find.text('Need help?'), findsOneWidget);
  });

  testWidgets('tapping the button opens the Quick help sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickHelpButton(onStartRecording: () async {}),
        ),
      ),
    );

    await tester.tap(find.text('Need help?'));
    await tester.pumpAndSettle();

    expect(find.text('Need help now?'), findsOneWidget);
    expect(find.text('I do not know what to record'), findsOneWidget);
  });
}
