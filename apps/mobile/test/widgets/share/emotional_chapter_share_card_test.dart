import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/share/emotional_chapter_share.dart';
import 'package:archiveme_mobile/widgets/share/emotional_chapter_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paints a quiet chapter at a 4:5 share size', (tester) async {
    final key = GlobalKey();
    const chapter = EmotionalChapterShare(
      id: 'chapter-1',
      line: 'This was before things got quieter.',
      beforeLabel: 'Earlier',
      nowLabel: 'Quieter',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmotionalChapterShareCard(
            chapter: chapter,
            boundaryKey: key,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('This was before things got quieter.'),
      findsOneWidget,
    );
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      tester.getSize(find.byKey(key)),
      const Size(360, 450),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(key),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as EmotionalChapterSharePainter;
    expect(painter.line, 'This was before things got quieter.');
    expect(painter.beforeLabel, 'Earlier');
    expect(painter.nowLabel, 'Quieter');
  });

  test('saves share-card bytes as a png file', () async {
    final dir = Directory.systemTemp.createTempSync('chapter-share');
    final file = await EmotionalChapterShareCard.writePngFile(
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      filename: 'chapter.png',
      directory: dir,
    );
    expect(await file.readAsBytes(), [137, 80, 78, 71, 13, 10, 26, 10]);
    dir.deleteSync(recursive: true);
  });

  testWidgets('a promotional line is left off the card', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmotionalChapterShareCard(
            boundaryKey: key,
            chapter: const EmotionalChapterShare(
              id: 'loud',
              line: 'Start your healing journey',
            ),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Start your healing journey'), findsNothing);
    expect(tester.getSemantics(find.byKey(key)).label, isEmpty);
  });

  test('promotional chapter lines are not shareable', () {
    expect(
      EmotionalChapterShare.isQuiet('Start your healing journey'),
      isFalse,
    );
    expect(EmotionalChapterShare.isQuiet('14 days quieter'), isFalse);
  });
}
