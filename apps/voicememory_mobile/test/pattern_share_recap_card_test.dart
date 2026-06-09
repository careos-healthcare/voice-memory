import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_share_recap_model.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_share_recap_card.dart';

PatternShareRecap _recap() => PatternShareRecap(
      id: 'share_weekly_1',
      createdAt: DateTime(2026, 6, 4),
      type: PatternShareRecapType.weekly,
      title: 'This week\u2019s pattern',
      body: 'This pattern kept showing up this week.',
      lines: const [
        'You checked it 4 times and caught it more than once.',
        'It often starts around: before saying yes',
        'Next check: What happens right before it starts?',
      ],
      nextQuestion: 'What happens right before it starts?',
      plainText: 'This week\u2019s pattern\n\nThis pattern kept showing up '
          'this week.\n\n- You checked it 4 times and caught it more than '
          'once.\n\nMade with ArchiveMe',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    clipboardText = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform,
        (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('card shows "Keep this pattern" with preview and buttons',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PatternShareRecapCard(recap: _recap()),
          ),
        ),
      ),
    );

    expect(find.text('Keep this pattern'), findsOneWidget);
    expect(find.text('This week\u2019s pattern'), findsOneWidget);
    expect(find.text('Copy recap'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('Copy recap writes text and shows a confirmation',
      (tester) async {
    final recap = _recap();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternShareRecapCard(recap: recap),
        ),
      ),
    );

    await tester.tap(find.text('Copy recap'));
    await tester.pump();

    expect(clipboardText, recap.plainText);
    expect(find.text('Recap copied.'), findsOneWidget);
  });
}
