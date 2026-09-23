import 'dart:io';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A capture or file-access failure while exporting an insight card.
class ArchiveShareCardCaptureException implements Exception {
  const ArchiveShareCardCaptureException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// One insight and the moments behind it, ready to paint as a share image.
class ArchiveShareCardContent {
  const ArchiveShareCardContent({
    required this.insight,
    this.supportingLines = const [],
    this.evidenceEntryIds = const [],
  });

  final String insight;
  final List<String> supportingLines;
  final List<String> evidenceEntryIds;

  String get shareText {
    final lines = supportingLines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3);
    final body = lines.join('\n');
    final headline = insight.trim();
    if (body.isEmpty) return headline;
    return '$headline\n\n$body';
  }
}

/// Warm share card. [RepaintBoundary] is the only region captured as an image.
class ArchiveShareCard extends StatelessWidget {
  const ArchiveShareCard({
    required this.content,
    required this.boundaryKey,
    super.key,
  });

  final ArchiveShareCardContent content;
  final GlobalKey boundaryKey;

  static const double logicalWidth = 360;
  static const double logicalHeight = 480;

  static String timestampedPngName([DateTime? capturedAt]) {
    final stamp = (capturedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return 'archive-share-card-$stamp.png';
  }

  /// True when the boundary still needs a frame, which would snapshot blank.
  ///
  /// `debugNeedsPaint` is only assigned in debug builds, so release skips it.
  static bool frameNeedsPaint(RenderRepaintBoundary boundary) {
    if (!kDebugMode) return false;
    return boundary.debugNeedsPaint;
  }

  /// Resolves the capture boundary after null and frame checks.
  static RenderRepaintBoundary readyBoundary(GlobalKey boundaryKey) {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw const ArchiveShareCardCaptureException(
        'The card is not on screen yet.',
      );
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw const ArchiveShareCardCaptureException(
        'The card is not ready to capture.',
      );
    }
    if (frameNeedsPaint(renderObject) || renderObject.size.isEmpty) {
      throw const ArchiveShareCardCaptureException(
        'The card is still painting, so the snapshot would be blank.',
      );
    }
    return renderObject;
  }

  static Future<File> writePngFile({
    required Uint8List bytes,
    required String filename,
    Directory? directory,
  }) async {
    if (bytes.isEmpty) {
      throw const ArchiveShareCardCaptureException('The card image was empty.');
    }
    final Directory dir;
    if (directory != null) {
      dir = directory;
    } else {
      try {
        dir = await getTemporaryDirectory();
      } on Object catch (error) {
        throw ArchiveShareCardCaptureException(
          'Could not open a temporary folder for the share image.',
          cause: error,
        );
      }
    }
    final file = File('${dir.path}/$filename');
    try {
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (error) {
      await _deleteIfPresent(file);
      throw ArchiveShareCardCaptureException(
        'Could not write the share image. Check storage access and try again.',
        cause: error,
      );
    }
    return file;
  }

  /// Reads PNG bytes from a painted boundary at 3x resolution.
  static Future<Uint8List> pngBytesFromBoundary(
    RenderRepaintBoundary boundary,
  ) async {
    if (frameNeedsPaint(boundary) || boundary.size.isEmpty) {
      throw const ArchiveShareCardCaptureException(
        'The card is still painting, so the snapshot would be blank.',
      );
    }
    final ui.Image image;
    try {
      image = await boundary.toImage(pixelRatio: 3.0);
    } on Object catch (error) {
      throw ArchiveShareCardCaptureException(
        'The card could not be painted for sharing.',
        cause: error,
      );
    }
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || byteData.lengthInBytes == 0) {
        throw const ArchiveShareCardCaptureException(
          'The card image was empty.',
        );
      }
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } on ArchiveShareCardCaptureException {
      rethrow;
    } on Object catch (error) {
      throw ArchiveShareCardCaptureException(
        'The card image could not be encoded.',
        cause: error,
      );
    } finally {
      image.dispose();
    }
  }

  /// Writes a timestamped PNG, shares it, then deletes the temp file.
  static Future<XFile> sharePngBytes({
    required Uint8List bytes,
    String text = '',
    Directory? directory,
    DateTime? capturedAt,
    Future<void> Function(XFile file, String text)? shareFile,
  }) async {
    final file = await writePngFile(
      bytes: bytes,
      filename: timestampedPngName(capturedAt),
      directory: directory,
    );
    final xFile = XFile(file.path, mimeType: 'image/png');
    final sender = shareFile ?? _shareWithSystemSheet;
    ArchiveShareCardCaptureException? failure;
    try {
      await sender(xFile, text);
    } on FileSystemException catch (error) {
      failure = ArchiveShareCardCaptureException(
        'Could not share this card. Check file access and try again.',
        cause: error,
      );
    } finally {
      await _deleteIfPresent(file);
    }
    if (failure != null) throw failure;
    return xFile;
  }

  /// Captures the card, writes a temporary PNG, and opens the share sheet.
  static Future<XFile> exportCard(
    GlobalKey boundaryKey, {
    String text = '',
    Directory? directory,
    DateTime? capturedAt,
    Future<void> Function(XFile file, String text)? shareFile,
  }) async {
    final boundary = readyBoundary(boundaryKey);
    final bytes = await pngBytesFromBoundary(boundary);
    return sharePngBytes(
      bytes: bytes,
      text: text,
      directory: directory,
      capturedAt: capturedAt,
      shareFile: shareFile,
    );
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Leaving a temp file behind is safer than hiding the original failure.
    }
  }

  static Future<void> _shareWithSystemSheet(XFile file, String text) {
    return Share.shareXFiles(
      [file],
      text: text,
      subject: 'ArchiveMe',
    );
  }

  @override
  Widget build(BuildContext context) {
    final insight = content.insight.trim();
    final lines = content.supportingLines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .toList();

    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        width: logicalWidth,
        height: logicalHeight,
        child: DecoratedBox(
          key: const Key('archive_share_card'),
          decoration: const BoxDecoration(
            color: ArchiveDesignTokens.background,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ArchiveDesignTokens.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Insight',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: ArchiveDesignTokens.accent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  insight,
                  key: const Key('archive_share_card_insight'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: ArchiveDesignTokens.fontSection,
                    fontWeight: ArchiveDesignTokens.weightSection,
                    height: ArchiveDesignTokens.leadingSection,
                    color: ArchiveDesignTokens.foreground,
                  ),
                ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    height: 1,
                    color: ArchiveDesignTokens.border,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'From your moments',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ArchiveDesignTokens.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final line in lines) ...[
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: ArchiveDesignTokens.fontBody,
                        height: ArchiveDesignTokens.leadingBody,
                        color: ArchiveDesignTokens.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const Spacer(),
                const Text(
                  'ArchiveMe',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: ArchiveDesignTokens.muted,
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

/// On-screen card with a reachable evidence link and a native share action.
class ArchiveShareCardPanel extends StatefulWidget {
  const ArchiveShareCardPanel({
    required this.content,
    super.key,
    this.onViewEvidence,
    this.shareFile,
    this.captureDirectory,
  });

  final ArchiveShareCardContent content;
  final VoidCallback? onViewEvidence;
  final Future<void> Function(XFile file, String text)? shareFile;
  final Directory? captureDirectory;

  @override
  State<ArchiveShareCardPanel> createState() => _ArchiveShareCardPanelState();
}

class _ArchiveShareCardPanelState extends State<ArchiveShareCardPanel> {
  final GlobalKey _boundaryKey = GlobalKey();
  var _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await ArchiveShareCard.exportCard(
        _boundaryKey,
        text: widget.content.shareText,
        shareFile: widget.shareFile,
        directory: widget.captureDirectory,
      );
    } on ArchiveShareCardCaptureException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on FileSystemException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not share this card. Check file access and try again.',
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share this card.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('archive_share_card_panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArchiveShareCard(content: widget.content, boundaryKey: _boundaryKey),
        if (widget.content.evidenceEntryIds.isNotEmpty ||
            widget.onViewEvidence != null)
          ViewEvidenceInlineLink(
            entryIds: widget.content.evidenceEntryIds,
            surface: 'archive_share_card',
            claimContext: widget.content.insight,
            onViewEvidence: widget.onViewEvidence,
          ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('archive_share_card_share'),
          onPressed: _sharing ? null : _share,
          child: Text(_sharing ? 'Preparing…' : 'Share card'),
        ),
      ],
    );
  }
}
