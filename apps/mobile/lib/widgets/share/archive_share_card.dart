import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Captures the card, writes a temporary PNG, and opens the system share sheet.
  static Future<XFile> exportCard(
    GlobalKey boundaryKey, {
    String text = '',
    Directory? directory,
    Future<void> Function(XFile file, String text)? shareFile,
  }) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Archive share card PNG was empty.');
    }
    final file = await writePngFile(
      bytes: byteData.buffer.asUint8List(),
      filename: 'archive-share-card.png',
      directory: directory,
    );
    final xFile = XFile(file.path, mimeType: 'image/png');
    final sender = shareFile ?? _shareWithSystemSheet;
    await sender(xFile, text);
    return xFile;
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
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share this card: $error')),
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
