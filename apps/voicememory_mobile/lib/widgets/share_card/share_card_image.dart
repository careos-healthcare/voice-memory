import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/share_card/share_card_copy.dart';
import '../../features/share_card/share_card_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/voicememory_cards.dart';

/// Fixed-size privacy-safe share card for PNG export.
class ShareCardImage extends StatelessWidget {
  const ShareCardImage({
    super.key,
    required this.model,
    this.exportKey,
    this.fixedWidth = exportWidth,
  });

  final ShareCardModel model;
  final GlobalKey? exportKey;
  final double fixedWidth;

  static const double exportWidth = 360;
  static const double exportMinHeight = 360;

  @override
  Widget build(BuildContext context) {
    final key = exportKey ?? GlobalKey();

    return RepaintBoundary(
      key: key,
      child: SizedBox(
        width: fixedWidth,
        child: Container(
          key: const Key('share_card_image'),
          width: fixedWidth,
          constraints: const BoxConstraints(minHeight: exportMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7F8FA), Color(0xFFEEF2F7)],
            ),
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            boxShadow: VoiceMemoryCards.standard().boxShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                ShareCardCopy.headline,
                key: const Key('share_card_headline'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                model.displayPatternLabel,
                key: const Key('share_card_pattern_label'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                model.relatedMomentsLine,
                key: const Key('share_card_related_moments'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if (model.hasChangeNoticed) ...[
                const SizedBox(height: 8),
                Text(
                  ShareCardCopy.changeNoticedLine,
                  key: const Key('share_card_change_noticed'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                ShareCardCopy.footer,
                key: const Key('share_card_footer'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<File> renderPngFile({
    required GlobalKey boundaryKey,
    required String filename,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Share card not ready to render');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode PNG');
    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> sharePngViaSheet({
    required GlobalKey boundaryKey,
    required ShareCardModel model,
  }) async {
    final file = await renderPngFile(
      boundaryKey: boundaryKey,
      filename: model.pngFilename,
    );
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'image/png'),
    ]);
  }
}
