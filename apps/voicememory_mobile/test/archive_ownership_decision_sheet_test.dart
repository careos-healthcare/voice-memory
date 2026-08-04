import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_ownership/archive_ownership_decision_service.dart';
import 'package:voicememory_mobile/features/archive_ownership/archive_ownership_decision_sheet.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';

void main() {
  const summary = UnclaimedArchiveSummary(
    sourceArchiveId: 'guest-archive',
    ownerKind: LocalArchiveOwnerKind.guest,
    momentCount: 3,
    earliestAt: null,
    latestAt: null,
  );

  Future<Map<String, int>> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final taps = <String, int>{'keep': 0, 'move': 0, 'export': 0, 'delete': 0};
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: ArchiveOwnershipDecisionSheet(
            summary: summary,
            onKeepSeparate: () => taps['keep'] = taps['keep']! + 1,
            onMoveToAccount: () => taps['move'] = taps['move']! + 1,
            onExport: () => taps['export'] = taps['export']! + 1,
            onDelete: () => taps['delete'] = taps['delete']! + 1,
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('states the position and offers all four choices', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(UnclaimedArchiveSummary.prompt), findsOneWidget);
    expect(find.textContaining('3 saved moments'), findsOneWidget);
    expect(find.text('Keep separate'), findsOneWidget);
    expect(find.text('Move to this account'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('never renders saved content on the decision surface', (
    tester,
  ) async {
    await pump(tester);

    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      expect(widget.data ?? '', isNot(contains('"')));
    }
    expect(find.textContaining('transcript'), findsNothing);
  });

  testWidgets('no choice is taken until the user picks one', (tester) async {
    final taps = await pump(tester);

    expect(taps.values.every((count) => count == 0), isTrue);

    await tester.tap(find.text('Keep separate'));
    await tester.pump();

    expect(taps['keep'], 1);
    expect(taps['move'], 0);
  });

  testWidgets('every action clears the minimum tap target', (tester) async {
    await pump(tester);

    for (final element in find.byType(TextButton).evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('renders on a dark theme without light-only colours', (
    tester,
  ) async {
    await pump(tester, brightness: Brightness.dark);

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(ArchiveOwnershipDecisionSheet),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      material.color,
      ThemeData(brightness: Brightness.dark).colorScheme.surface,
    );
  });
}
