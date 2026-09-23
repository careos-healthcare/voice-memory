import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/widgets/share/archive_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const content = ArchiveShareCardContent(
    insight: 'Evenings are quieter after a walk.',
    supportingLines: ['Left before dinner.', 'Called one friend.'],
    evidenceEntryIds: ['moment-1'],
  );

  testWidgets('paints the insight inside a capture boundary', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveShareCard(content: content, boundaryKey: key),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(find.text('Insight'), findsOneWidget);
    expect(find.text('Evenings are quieter after a walk.'), findsOneWidget);
    expect(find.text('From your moments'), findsOneWidget);
    expect(find.text('Left before dinner.'), findsOneWidget);
    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(tester.getSize(find.byKey(key)), const Size(360, 480));
    expect(find.textContaining('theory'), findsNothing);
  });

  testWidgets('keeps a reachable evidence link beside the share action', (
    tester,
  ) async {
    var sawEvidence = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveShareCardPanel(
            content: content,
            onViewEvidence: () => sawEvidence = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('archive_share_card_panel')), findsOneWidget);
    expect(find.text('Share card'), findsOneWidget);
    await tester.tap(find.text('· View evidence'));
    await tester.pump();
    expect(sawEvidence, isTrue);
  });

  test('writes the captured bytes as a png', () async {
    final dir = Directory.systemTemp.createTempSync('archive-share-card');
    final file = await ArchiveShareCard.writePngFile(
      bytes: Uint8List.fromList(const [137, 80, 78, 71, 13, 10, 26, 10]),
      filename: 'archive-share-card.png',
      directory: dir,
    );
    expect(await file.readAsBytes(), [137, 80, 78, 71, 13, 10, 26, 10]);
    dir.deleteSync(recursive: true);
  });

  test('encodes raw rgba pixels as a png', () {
    final png = ArchiveShareCard.pngBytesFromRgba(
      rgba: Uint8List.fromList(const [255, 0, 0, 255]),
      width: 1,
      height: 1,
    );
    final decoded = img.decodePng(png);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1);
    expect(decoded.height, 1);
    final pixel = decoded.getPixel(0, 0);
    expect(pixel.r, 255);
    expect(pixel.g, 0);
    expect(pixel.b, 0);
  });

  test('share text keeps the insight and the moments behind it', () {
    expect(
      content.shareText,
      'Evenings are quieter after a walk.\n\n'
      'Left before dinner.\n'
      'Called one friend.',
    );
  });
}
