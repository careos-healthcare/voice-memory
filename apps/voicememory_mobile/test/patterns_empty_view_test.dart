import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';

void main() {
  testWidgets('patterns empty state shows clear copy and one CTA', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PatternsEmptyView(fillViewport: false))),
    );
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsEarlyStateBody), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsEmptyCta), findsOneWidget);
    expect(find.text('How it works'), findsNothing);
    expect(find.text('Record one clear moment'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
    expect(find.textContaining('I want freedom'), findsNothing);
    expect(find.textContaining('I talk about achievement'), findsNothing);
    expect(find.textContaining('pattern that used to drive me'), findsNothing);
  });

  testWidgets('patterns one-moment state prompts next recording', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PatternsEmptyView(fillViewport: false, reflectionCount: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.patternsOneMomentTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsOneMomentBody), findsOneWidget);
    expect(find.text(ConsumerUiCopy.patternsOneMomentCta), findsOneWidget);
  });

  testWidgets('patterns empty is readable on iPad width', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PatternsEmptyView(fillViewport: false))),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.text(ConsumerUiCopy.patternsEmptyPageTitle),
    );
    expect(title.style?.fontSize ?? 0, greaterThanOrEqualTo(26));
  });
}
