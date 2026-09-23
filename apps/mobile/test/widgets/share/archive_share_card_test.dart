import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/widgets/share/archive_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

    final boundary = ArchiveShareCard.readyBoundary(key);
    expect(boundary, isA<RenderRepaintBoundary>());
    expect(boundary.debugNeedsPaint, isFalse);
    expect(boundary.size, const Size(360, 480));
  });

  testWidgets('refuses a capture while the card still needs paint', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveShareCard(content: content, boundaryKey: key),
        ),
      ),
    );
    await tester.pump();

    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      fail('missing capture boundary');
    }
    renderObject.markNeedsPaint();
    expect(renderObject.debugNeedsPaint, isTrue);
    expect(
      () => ArchiveShareCard.readyBoundary(key),
      throwsA(
        isA<ArchiveShareCardCaptureException>().having(
          (error) => error.message,
          'message',
          'Frame not fully painted',
        ),
      ),
    );
  });

  testWidgets('rejects a missing or zero-size capture boundary', (
    tester,
  ) async {
    expect(
      () => ArchiveShareCard.readyBoundary(GlobalKey()),
      throwsA(
        isA<ArchiveShareCardCaptureException>().having(
          (error) => error.message,
          'message',
          'Frame not fully painted',
        ),
      ),
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox.square(dimension: 0),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      () => ArchiveShareCard.readyBoundary(key),
      throwsA(
        isA<ArchiveShareCardCaptureException>().having(
          (error) => error.message,
          'message',
          'Frame not fully painted',
        ),
      ),
    );
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

  testWidgets('shows a snackbar when the frame is not painted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ArchiveShareCardPanel(content: content)),
      ),
    );
    await tester.pump();

    tester.binding.addPostFrameCallback((_) {
      for (final boundary in tester.renderObjectList<RenderRepaintBoundary>(
        find.byType(RepaintBoundary),
      )) {
        if (boundary.size == const Size(360, 480)) {
          boundary.markNeedsPaint();
        }
      }
    });
    await tester.tap(find.byKey(const Key('archive_share_card_share')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Frame not fully painted'), findsOneWidget);
  });

  test('writes a timestamped png and deletes it after sharing', () async {
    final dir = Directory.systemTemp.createTempSync('archive-share-card');
    final capturedAt = DateTime.utc(2026, 9, 23, 12);
    final png = Uint8List.fromList(const [137, 80, 78, 71, 13, 10, 26, 10]);
    String? sharedPath;
    String? sharedMime;
    final exported = await ArchiveShareCard.sharePngBytes(
      bytes: png,
      text: content.shareText,
      directory: dir,
      capturedAt: capturedAt,
      shareFile: (file, text) async {
        sharedPath = file.path;
        sharedMime = file.mimeType;
        expect(text, content.shareText);
        expect(await File(file.path).readAsBytes(), png);
      },
    );
    final stamp = capturedAt.millisecondsSinceEpoch;
    expect(exported.path, endsWith('archive-share-card-$stamp.png'));
    expect(exported.mimeType, 'image/png');
    expect(sharedPath, exported.path);
    expect(sharedMime, 'image/png');
    expect(await File(exported.path).exists(), isFalse);
    dir.deleteSync(recursive: true);
  });

  test('reports a storage failure and leaves no partial file', () async {
    final dir = Directory.systemTemp.createTempSync('archive-share-card');
    final missing = Directory('${dir.path}/missing');
    await expectLater(
      ArchiveShareCard.writePngFile(
        bytes: Uint8List.fromList(const [137, 80, 78, 71]),
        filename: 'archive-share-card.png',
        directory: missing,
      ),
      throwsA(
        isA<ArchiveShareCardCaptureException>().having(
          (error) => error.message,
          'message',
          contains('storage access'),
        ),
      ),
    );
    expect(dir.listSync(), isEmpty);
    dir.deleteSync(recursive: true);
  });

  test('deletes the temp png when sharing is cancelled', () async {
    final dir = Directory.systemTemp.createTempSync('archive-share-card');
    await expectLater(
      ArchiveShareCard.sharePngBytes(
        bytes: Uint8List.fromList(const [137, 80, 78, 71]),
        directory: dir,
        capturedAt: DateTime.utc(2026, 9, 23, 12, 1),
        shareFile: (file, text) async {
          throw Exception('cancelled');
        },
      ),
      throwsA(
        isA<ArchiveShareCardCaptureException>().having(
          (error) => error.message,
          'message',
          'Could not share this card.',
        ),
      ),
    );
    expect(dir.listSync(), isEmpty);
    dir.deleteSync(recursive: true);
  });

  test('deletes the temp png when sharing is denied', () async {
    final dir = Directory.systemTemp.createTempSync('archive-share-card');
    await expectLater(
      ArchiveShareCard.sharePngBytes(
        bytes: Uint8List.fromList(const [137, 80, 78, 71]),
        directory: dir,
        capturedAt: DateTime.utc(2026, 9, 23, 12),
        shareFile: (file, text) async {
          throw const FileSystemException('denied');
        },
      ),
      throwsA(
        isA<ArchiveShareCardCaptureException>().having(
          (error) => error.message,
          'message',
          contains('file access'),
        ),
      ),
    );
    expect(dir.listSync(), isEmpty);
    dir.deleteSync(recursive: true);
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
