import 'package:archiveme_mobile/features/archive/ui/remote_processing_choice_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/remote_processing_skipped_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains the skipped deeper read and exposes the choice CTA', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RemoteProcessingSkippedCard(
            onChooseWhatLeaves: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.byKey(RemoteProcessingSkippedCard.cardKey), findsOneWidget);
    expect(
      find.text(RemoteProcessingChoiceCopy.skippedNote),
      findsOneWidget,
    );
    expect(
      find.text(RemoteProcessingChoiceCopy.chooseWhatLeavesTitle),
      findsOneWidget,
    );
    expect(
      find.textContaining('You turned off remote processing'),
      findsNothing,
    );
    expect(find.textContaining('shown below'), findsNothing);

    await tester.tap(find.byKey(RemoteProcessingSkippedCard.ctaKey));
    expect(opened, isTrue);
  });
}
