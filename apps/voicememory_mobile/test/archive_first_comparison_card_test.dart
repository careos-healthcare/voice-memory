import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_first_comparison_display.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_first_comparison_card.dart';

void main() {
  group('ArchiveFirstComparisonCard', () {
    testWidgets('grounded display shows connect body and view evidence CTA', (
      tester,
    ) async {
      var evidenceTapped = false;
      var addTapped = false;
      const connectBody =
          'This may connect to: "had no capacity". What changed: The latest moment adds: "one more thing".';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveFirstComparisonCard(
              display: ArchiveFirstComparisonDisplay(
                show: true,
                title: VisibleArchiveProofCopy.archiveFirstComparisonTitle,
                body: connectBody,
                primaryIsViewEvidence: true,
                hasGroundedPattern: true,
              ),
              onViewEvidence: () => evidenceTapped = true,
              onAddAnotherMoment: () => addTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('archive_first_comparison_card')), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.archiveFirstComparisonTitle),
        findsOneWidget,
      );
      expect(find.text(connectBody), findsOneWidget);
      expect(find.text(PostSaveFocusedActionsCopy.viewEvidence), findsOneWidget);
      expect(
        find.text(PostSaveFocusedActionsCopy.addOneMoreMoment),
        findsOneWidget,
      );

      await tester.tap(find.text(PostSaveFocusedActionsCopy.viewEvidence));
      await tester.pump();
      expect(evidenceTapped, isTrue);

      await tester.tap(find.text(PostSaveFocusedActionsCopy.addOneMoreMoment));
      await tester.pump();
      expect(addTapped, isTrue);
    });

    testWidgets('ungrounded display uses add moment as primary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveFirstComparisonCard(
              display: const ArchiveFirstComparisonDisplay(
                show: true,
                title: VisibleArchiveProofCopy.twoEntryCompareTitle,
                body: VisibleArchiveProofCopy.twoEntryBodyUngrounded,
                primaryIsViewEvidence: false,
                hasGroundedPattern: false,
              ),
              onViewEvidence: () {},
              onAddAnotherMoment: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(PostSaveFocusedActionsCopy.viewEvidence), findsNothing);
      expect(find.byKey(const Key('archive_first_comparison_add_moment_cta')), findsOneWidget);
    });
  });
}
