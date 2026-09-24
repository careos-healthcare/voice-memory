import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/features/share/emotional_chapter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

/// 4:5 black share card for an emotional chapter. The picture is painted,
/// then saved from the [RepaintBoundary].
class EmotionalChapterShareCard extends StatelessWidget {
  const EmotionalChapterShareCard({
    required this.chapter,
    required this.boundaryKey,
    super.key,
  });

  final EmotionalChapterShare chapter;
  final GlobalKey boundaryKey;

  /// Feed post size at a 3× export: 1080×1350.
  static const double logicalWidth = 360;
  static const double logicalHeight = 450;

  static Future<ui.Image> captureImage(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Share card is not ready to capture.');
    }
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  static Future<File> download(
    GlobalKey boundaryKey, {
    required String filename,
    Directory? directory,
    double pixelRatio = 3,
  }) async {
    final image = await captureImage(boundaryKey, pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Share card PNG was empty.');
    }
    return writePngFile(
      bytes: bytes.buffer.asUint8List(),
      filename: filename,
      directory: directory,
    );
  }

  static Future<File> writePngFile({
    required Uint8List bytes,
    required String filename,
    Directory? directory,
  }) async {
    final dir = directory ?? await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final line = chapter.canShare ? chapter.line.trim() : '';
    return RepaintBoundary(
      key: boundaryKey,
      child: Semantics(
        label: line,
        child: SizedBox(
          width: logicalWidth,
          height: logicalHeight,
          child: CustomPaint(
            painter: EmotionalChapterSharePainter(
              line: line,
              beforeLabel: chapter.canShare ? chapter.beforeLabel : null,
              nowLabel: chapter.canShare ? chapter.nowLabel : null,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class EmotionalChapterSharePainter extends CustomPainter {
  const EmotionalChapterSharePainter({
    required this.line,
    this.beforeLabel,
    this.nowLabel,
  });

  final String line;
  final String? beforeLabel;
  final String? nowLabel;

  static const _black = Color(0xFF000000);
  static const _text = Color(0xFFF2F2F2);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _black);
    final maxWidth = size.width - 64;
    var y = 56.0;

    final before = beforeLabel?.trim();
    if (before != null && before.isNotEmpty) {
      y = _draw(
        canvas,
        'Before',
        y,
        maxWidth,
        const TextStyle(
          color: Color(0x6BF2F2F2),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
      );
      y = _draw(
        canvas,
        before,
        y + 8,
        maxWidth,
        const TextStyle(
          color: Color(0x9EF2F2F2),
          fontSize: 16,
          height: 1.4,
        ),
      );
      y += 28;
    }

    y = _draw(
      canvas,
      line,
      y,
      maxWidth,
      const TextStyle(
        color: _text,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        height: 1.25,
        letterSpacing: -0.3,
      ),
    );

    final now = nowLabel?.trim();
    if (now != null && now.isNotEmpty) {
      y = _draw(
        canvas,
        'Now',
        y + 28,
        maxWidth,
        const TextStyle(
          color: Color(0x6BF2F2F2),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
      );
      _draw(
        canvas,
        now,
        y + 8,
        maxWidth,
        const TextStyle(
          color: Color(0x9EF2F2F2),
          fontSize: 16,
          height: 1.4,
        ),
      );
    }

    _draw(
      canvas,
      'ArchiveMe',
      size.height - 48,
      maxWidth,
      const TextStyle(
        color: Color(0x52F2F2F2),
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }

  double _draw(
    Canvas canvas,
    String text,
    double top,
    double maxWidth,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 6,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(32, top));
    return top + painter.height;
  }

  @override
  bool shouldRepaint(EmotionalChapterSharePainter oldDelegate) {
    return line != oldDelegate.line ||
        beforeLabel != oldDelegate.beforeLabel ||
        nowLabel != oldDelegate.nowLabel;
  }
}
