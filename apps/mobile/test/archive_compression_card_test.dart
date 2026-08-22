import 'package:archiveme_mobile/features/archive_compression/archive_compression_model.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_compression_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveMomentGroup _group() => ArchiveMomentGroup(
  id: 'g1',
  title: 'Taking responsibility before asking for help',
  momentIds: const ['m1', 'm2', 'm3', 'm4', 'm5'],
  patternTitle: 'Taking responsibility before asking for help',
  tags: const ['pressure', 'work', 'helped'],
  firstDate: DateTime(2026, 5, 12),
  lastDate: DateTime(2026, 5, 26),
  count: 5,
  suggestedAction: ArchiveCompressionSuggestedAction.keepTogether,
);

Future<void> _pump(
  WidgetTester tester, {
  ArchiveMomentGroup? group,
  Future<void> Function(ArchiveMomentGroup)? onKept,
  Future<void> Function(ArchiveMomentGroup)? onSplit,
  Future<void> Function(ArchiveMomentGroup)? onHidden,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ArchiveCompressionCard(
          group: group ?? _group(),
          onKept: onKept,
          onSplit: onSplit,
          onHidden: onHidden,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders group title, count, and actions', (tester) async {
    await _pump(tester);

    expect(find.text('Clean up your archive'), findsOneWidget);
    expect(find.text('ArchiveMe found similar moments.'), findsOneWidget);
    expect(
      find.text('Taking responsibility before asking for help'),
      findsOneWidget,
    );
    expect(find.text('5 moments · 2 weeks'), findsOneWidget);
    expect(find.text('Keep as one pattern'), findsOneWidget);
    expect(find.text('Split this'), findsOneWidget);
    expect(find.text('Hide group'), findsOneWidget);
  });

  testWidgets('actions call handlers without delete language', (tester) async {
    ArchiveMomentGroup? kept;
    ArchiveMomentGroup? split;
    ArchiveMomentGroup? hidden;

    await _pump(
      tester,
      onKept: (g) async => kept = g,
      onSplit: (g) async => split = g,
      onHidden: (g) async => hidden = g,
    );

    expect(find.textContaining('delete'), findsNothing);
    expect(find.textContaining('remove'), findsNothing);

    await tester.tap(find.text('Keep as one pattern'));
    await tester.pump();
    expect(kept?.id, 'g1');

    await tester.tap(find.text('Split this'));
    await tester.pump();
    expect(split?.id, 'g1');

    await tester.tap(find.text('Hide group'));
    await tester.pump();
    expect(hidden?.id, 'g1');
  });
}