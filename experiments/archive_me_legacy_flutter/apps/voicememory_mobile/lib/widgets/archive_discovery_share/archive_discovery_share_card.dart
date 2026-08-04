import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/archive_discovery_share/archive_discovery_share_analytics.dart';
import '../../features/archive_discovery_share/archive_discovery_share_card_model.dart';
import '../../features/archive_discovery_share/archive_discovery_share_copy.dart';
import '../../features/archive_discovery_share/archive_discovery_share_palette.dart';
import '../../features/archive_discovery_share/archive_discovery_share_types.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_typography.dart';

/// Archive Discovery Share Cards V2 — premium PNG export with light/dark palettes.
class ArchiveDiscoveryShareCard extends StatelessWidget {
  const ArchiveDiscoveryShareCard({
    super.key,
    required this.card,
    this.exportKey,
    this.palette,
    this.fixedWidth,
  });

  final ArchiveDiscoveryShareCardModel card;
  final GlobalKey? exportKey;
  final ArchiveDiscoverySharePalette? palette;

  /// When set (e.g. export width), card uses a fixed width for crisp PNGs.
  final double? fixedWidth;

  @override
  Widget build(BuildContext context) {
    final colors = palette ?? ArchiveDiscoverySharePalette.fromContext(context);
    final width = fixedWidth ?? double.infinity;
    final key = exportKey ?? GlobalKey();

    return RepaintBoundary(
      key: key,
      child: SizedBox(
        width: width,
        child: Container(
          key: const Key('archive_discovery_share_card'),
          width: width,
          constraints: const BoxConstraints(
            minHeight: ArchiveDiscoveryShareCopy.exportMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.background, colors.backgroundGradientEnd],
            ),
            border: Border.all(color: colors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                card.introLine,
                style: VoiceMemoryTypography.sectionLabelStyle().copyWith(
                  fontSize: 13,
                  color: colors.headline,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                card.insight,
                key: const Key('archive_discovery_share_insight'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: colors.insight,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                card.evidenceLine,
                key: const Key('archive_discovery_share_evidence'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: colors.evidence,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                card.footer,
                key: const Key('archive_discovery_share_footer'),
                style: TextStyle(
                  fontSize: 16,
                  color: colors.footer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
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
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
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

  /// Opens the system share sheet with a PNG of this card.
  static Future<void> sharePngViaSheet({
    required GlobalKey boundaryKey,
    required ArchiveDiscoveryShareCardModel card,
    required String surface,
  }) async {
    final file = await renderPngFile(
      boundaryKey: boundaryKey,
      filename: card.pngFilename,
    );
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'image/png'),
    ], text: ArchiveDiscoveryShareCopy.shareSheetText);
    await ArchiveDiscoveryShareAnalytics.discoveryShared(
      cardType: card.type,
      cardId: card.id,
      surface: surface,
      exportMethod: 'share_sheet',
      evidenceRecordingCount: card.evidenceRecordingCount,
    );
  }

  /// Exports PNG and opens the share sheet (image only).
  static Future<void> exportPng({
    required GlobalKey boundaryKey,
    required ArchiveDiscoveryShareCardModel card,
    required String surface,
  }) async {
    final file = await renderPngFile(
      boundaryKey: boundaryKey,
      filename: card.pngFilename,
    );
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
    await ArchiveDiscoveryShareAnalytics.discoveryShared(
      cardType: card.type,
      cardId: card.id,
      surface: surface,
      exportMethod: 'png',
      evidenceRecordingCount: card.evidenceRecordingCount,
    );
  }
}

/// Type label chip for the share discoveries list.
class ArchiveDiscoveryShareCardTypeLabel extends StatelessWidget {
  const ArchiveDiscoveryShareCardTypeLabel({super.key, required this.type});

  final ArchiveDiscoveryShareCardType type;

  @override
  Widget build(BuildContext context) {
    return Text(
      type.displayLabel,
      style: const TextStyle(
        fontSize: 11,
        color: AppTheme.muted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
