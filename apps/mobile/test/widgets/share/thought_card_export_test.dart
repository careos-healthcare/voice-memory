import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/share/thought_card.dart';
import 'package:archiveme_mobile/widgets/share/thought_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

const _png = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];

void main() {
  test('anonymize drops the address, the number, and the named person', () {
    final line = ThoughtCardText.anonymize(
      'I kept thinking about the quiet room with Maya today. '
      'ada@example.com 555-010-0199',
    );

    expect(line, 'I kept thinking about the quiet room today.');
    expect(line.contains('Maya'), isFalse);
    expect(line.contains('@'), isFalse);
    expect(line.contains('555'), isFalse);
  });

  test(
    'share writes the PNG into the temp directory and opens the sheet',
    () async {
      final directory = await Directory.systemTemp.createTemp('thought-card');
      addTearDown(() => directory.delete(recursive: true));
      XFile? shared;

      final file = await ThoughtCardExport.share(
        boundaryKey: GlobalKey(),
        directory: directory,
        capture: (_) async => Uint8List.fromList(_png),
        present: (image) async {
          shared = image;
        },
      );

      expect(shared?.path, file.path);
      expect(shared?.mimeType, 'image/png');
      expect(file.parent.path, directory.path);
      expect(file.readAsBytesSync(), _png);
    },
  );

  testWidgets('the card shows the anonymized line and Share sits outside it', (
    tester,
  ) async {
    var shares = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThoughtCardShare(
            text:
                'I kept thinking about the quiet room with Maya today. ada@example.com',
            share: (boundaryKey) async {
              shares += 1;
              return File('thought-card.png');
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('I kept thinking about the quiet room today.'),
      findsOneWidget,
    );
    expect(find.textContaining('Maya'), findsNothing);
    expect(find.textContaining('ada@example.com'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('thought_card_surface')),
        matching: find.byKey(const Key('thought_card_line')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('thought_card_surface')),
        matching: find.text('Share'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('thought_card_share')));
    await tester.pump();
    expect(shares, 1);
  });
}
