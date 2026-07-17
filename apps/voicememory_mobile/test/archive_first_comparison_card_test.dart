import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_first_comparison_display.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_first_comparison_card.dart';

void main() {
  group('ArchiveFirstComparisonCard', () {
    testWidgets('grounded display shows one primary view evidence CTA', (
      tester,
    ) async {
      var evidenceTapped = false;
      var addTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveFirstComparisonCard(
              display: const ArchiveFirstComparisonDisplay(
                show: true,
                title: VisibleArchiveProofCopy.archiveFirstComparisonTitle,
                body: VisibleArchiveProofCopy.archiveFirstComparisonMayConnectBody,
                evidenceLine:
                    'You mentioned checking again before feeling done more than once.',
                whatChangedLine: 'The latest moment may be more about work.',
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
      expect(
        find.text(
          'You mentioned checking again before feeling done more than once.',
        ),
        findsOneWidget,
      );
      expect(find.text(PostSaveFocusedActionsCopy.viewEvidence), findsOneWidget);
      expect(
        find.text(PostSaveFocusedActionsCopy.addOneMoreMoment),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.archiveFirstComparisonWhatChangedLabel),
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
