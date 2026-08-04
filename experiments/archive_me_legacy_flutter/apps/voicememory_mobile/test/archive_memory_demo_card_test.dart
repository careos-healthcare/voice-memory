import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/archive_memory_demo_card.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: ArchiveMemoryDemoCard(onRecord: () {})),
    ),
  );
}

void main() {
  testWidgets('shows Day 1 / Day 3 / Day 7 example rows', (tester) async {
    await _pump(tester);
    expect(find.text(ConsumerUiCopy.archiveMemoryDemoTitle), findsOneWidget);
    expect(find.textContaining('Day 1:'), findsOneWidget);
    expect(find.textContaining('Day 3:'), findsOneWidget);
    expect(find.textContaining('Day 7:'), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.archiveMemoryDemoRememberLine),
      findsOneWidget,
    );
  });

  testWidgets('demo CTA fires onRecord', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ArchiveMemoryDemoCard(onRecord: () => tapped = true),
        ),
      ),
    );
    await tester.tap(find.text(ConsumerUiCopy.archiveMemoryDemoCta));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
