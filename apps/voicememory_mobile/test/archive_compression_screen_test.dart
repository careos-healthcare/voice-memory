import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_compression/archive_compression_model.dart';
import 'package:voicememory_mobile/screens/archive_compression_screen.dart';

ArchiveMomentGroup _group({String id = 'g1'}) => ArchiveMomentGroup(
      id: id,
      title: 'Taking responsibility before asking for help',
      momentIds: const ['m1', 'm2', 'm3'],
      patternTitle: 'Taking responsibility before asking for help',
      tags: const ['pressure', 'work'],
      firstDate: DateTime(2026, 5, 12),
      lastDate: DateTime(2026, 5, 26),
      count: 3,
      suggestedAction: ArchiveCompressionSuggestedAction.keepTogether,
    );

Future<void> _pump(
  WidgetTester tester, {
  Future<List<ArchiveMomentGroup>> Function()? loader,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ArchiveCompressionScreen(loader: loader),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('renders groups with actions', (tester) async {
    await _pump(
      tester,
      loader: () async => [_group(), _group(id: 'g2')],
    );

    expect(find.text('Clean up your archive'), findsOneWidget);
    expect(
      find.text('Group similar moments so your archive stays useful.'),
      findsOneWidget,
    );
    expect(find.text('Keep as one pattern'), findsNWidgets(2));
    expect(find.text('Hide group'), findsNWidgets(2));
  });

  testWidgets('empty state when no groups', (tester) async {
    await _pump(tester, loader: () async => const []);

    expect(find.text('Your archive is clean for now.'), findsOneWidget);
    expect(find.text('Keep as one pattern'), findsNothing);
  });

  testWidgets('kept action removes group from list', (tester) async {
    final kept = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveCompressionScreen(
          loader: () async => [_group()],
          onKept: (g) async => kept.add(g.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep as one pattern'));
    await tester.pumpAndSettle();

    expect(kept, ['g1']);
  });
}
