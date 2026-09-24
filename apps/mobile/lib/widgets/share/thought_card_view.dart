import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/features/share/thought_card.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures a [ThoughtCard] and opens the system share sheet.
abstract final class ThoughtCardExport {
  ThoughtCardExport._();

  /// 3× of the 360×450 card is a 1080×1350 PNG.
  static const double pixelRatio = 3;

  static Future<Uint8List> captureBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = pixelRatio,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Thought card is not ready to capture.');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Thought card PNG was empty.');
    }
    return bytes.buffer.asUint8List();
  }

  static Future<File> saveTemporaryPng(
    Uint8List bytes, {
    Directory? directory,
  }) async {
    final dir = directory ?? await getTemporaryDirectory();
    final name = 'thought-card-${DateTime.now().microsecondsSinceEpoch}.png';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> presentShareSheet(XFile file) {
    return Share.shareXFiles(
      [file],
      subject: 'Thought',
    );
  }

  /// Paints the boundary to a PNG, stores it in the temp directory, then
  /// opens the native share sheet.
  static Future<File> share({
    required GlobalKey boundaryKey,
    Directory? directory,
    Future<Uint8List> Function(GlobalKey boundaryKey)? capture,
    Future<void> Function(XFile file)? present,
  }) async {
    final bytes = await (capture ?? captureBoundary)(boundaryKey);
    final file = await saveTemporaryPng(bytes, directory: directory);
    await (present ?? presentShareSheet)(
      XFile(file.path, mimeType: 'image/png'),
    );
    return file;
  }
}

/// Anonymized quote card plus the Share control.
class ThoughtCardShare extends StatefulWidget {
  const ThoughtCardShare({
    required this.text,
    this.share,
    super.key,
  });

  final String text;

  /// Test seam. Production captures the card and opens the share sheet.
  final Future<File> Function(GlobalKey boundaryKey)? share;

  @override
  State<ThoughtCardShare> createState() => _ThoughtCardShareState();
}

class _ThoughtCardShareState extends State<ThoughtCardShare> {
  final GlobalKey _boundaryKey = GlobalKey();

  Future<void> _onShare() async {
    final line = ThoughtCardText.anonymize(widget.text);
    if (line.isEmpty) return;
    final export = widget.share ?? ThoughtCardExport.share;
    await export(_boundaryKey);
  }

  @override
  Widget build(BuildContext context) {
    final line = ThoughtCardText.anonymize(widget.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThoughtCard(boundaryKey: _boundaryKey, line: line),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('thought_card_share'),
          onPressed: line.isEmpty ? null : _onShare,
          child: const Text('Share'),
        ),
      ],
    );
  }
}

/// The painted card. The Share control stays outside this boundary.
class ThoughtCard extends StatelessWidget {
  const ThoughtCard({
    required this.boundaryKey,
    required this.line,
    super.key,
  });

  final GlobalKey boundaryKey;
  final String line;

  static const double logicalWidth = 360;
  static const double logicalHeight = 450;
  static const _black = Color(0xFF000000);
  static const _text = Color(0xFFF2F2F2);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        key: const Key('thought_card_surface'),
        width: logicalWidth,
        height: logicalHeight,
        child: ColoredBox(
          color: _black,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THOUGHT',
                  style: TextStyle(
                    color: Color(0x73F2F2F2),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  line,
                  key: const Key('thought_card_line'),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                const Text(
                  'ArchiveMe',
                  style: TextStyle(
                    color: Color(0x59F2F2F2),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
