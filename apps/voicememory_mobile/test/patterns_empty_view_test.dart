import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_first_archive_view.dart';

void main() {
  testWidgets('patterns empty state shows clear copy and one CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsOneWidget);
    expect(
      find.text(VisibleArchiveProofCopy.patternsEmptyPreviewBody),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.patternsEmptyCta), findsOneWidget);
    expect(find.text('Record one moment'), findsOneWidget);
    expect(find.text('Record first moment'), findsNothing);
    expect(find.text('How it works'), findsNothing);
    expect(find.text('Record one clear moment'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
    expect(find.textContaining('I want freedom'), findsNothing);
    expect(find.textContaining('I talk about achievement'), findsNothing);
    expect(find.textContaining('pattern that used to drive me'), findsNothing);
  });

  testWidgets('patterns first-archive view shows one-entry saved copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PatternsFirstArchiveView(
            fillViewport: false,
            savedEntryId: 'e1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(ConsumerUiCopy.patternsFirstEntrySavedTitle),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.patternsFirstEntrySavedBody),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.patternsFirstEntrySavedCta),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.patternsEmptyPageTitle), findsNothing);
    expect(find.text(ConsumerUiCopy.patternsEmptyCta), findsNothing);
  });

  testWidgets('patterns empty is readable on iPad width', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatternsEmptyView(fillViewport: false)),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.text(ConsumerUiCopy.patternsEmptyPageTitle),
    );
    expect(title.style?.fontSize ?? 0, greaterThanOrEqualTo(26));
  });
}
