import 'dart:io';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_models.dart';
import 'package:archiveme_mobile/features/evidence_artifact/evidence_artifact_copy.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_copy.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Fixed-size proof card for PNG export via [RepaintBoundary].
class EvidenceShareCard extends StatelessWidget {
  const EvidenceShareCard({
    required this.artifact, required this.redactQuotes, super.key,
    this.exportKey,
    this.fixedWidth = exportWidth,
  });

  final EvidenceProofArtifact artifact;
  final bool redactQuotes;
  final GlobalKey? exportKey;
  final double fixedWidth;

  static const double exportWidth = 360;
  static const double exportMinHeight = 480;

  @override
  Widget build(BuildContext context) {
    final key = exportKey ?? GlobalKey();
    final bandPalette = _paletteFor(artifact.confidenceBand);
    final dateFormat = DateFormat('MMM d, yyyy');

    return RepaintBoundary(
      key: key,
      child: SizedBox(
        width: fixedWidth,
        child: Container(
          key: const Key('evidence_share_card'),
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
                  color: VoiceMemoryColors.primaryIndigo,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                EvidenceArtifactCopy.shareCardHeadline,
                style: VoiceMemoryTypography.sectionLabelStyle(),
              ),
              const SizedBox(height: 16),
              Text(
                artifact.subjectTitle,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 22,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  artifact.stats.frequencyBadgeLabel,
                  style: VoiceMemoryTypography.bodyStyle().copyWith(
                    fontWeight: FontWeight.w700,
                    color: VoiceMemoryColors.primaryIndigo,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bandPalette.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bandPalette.border),
                ),
                child: Text(
                  bandPalette.label,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: bandPalette.foreground,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                PatternMatchQualityCopy.explanationFor(artifact.confidenceBand),
                style: VoiceMemoryTypography.secondaryStyle(),
              ),
              const SizedBox(height: 12),
              Text(
                artifact.stats.timespanLabel,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (artifact.stats.totalFrequency > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '${artifact.stats.occurrenceDensityPerWeek} '
                  '${EvidenceArtifactCopy.densityUnit}',
                  style: VoiceMemoryTypography.secondaryStyle(),
                ),
              ],
              if (artifact.hasCitations) ...[
                const SizedBox(height: 20),
                Text(
                  EvidenceArtifactCopy.timelineSection,
                  style: VoiceMemoryTypography.sectionLabelStyle(),
                ),
                const SizedBox(height: 10),
                for (final citation in artifact.citations.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(citation.recordedAt),
                          style: VoiceMemoryTypography.secondaryStyle().copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          redactQuotes
                              ? EvidenceArtifactCopy.redactedQuote
                              : citation.quote,
                          style: VoiceMemoryTypography.bodyStyle().copyWith(
                            height: 1.4,
                            fontStyle: redactQuotes
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: redactQuotes
                                ? VoiceMemoryColors.textSecondary
                                : VoiceMemoryColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                EvidenceArtifactCopy.shareCardFooter,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  fontWeight: FontWeight.w700,
                  color: VoiceMemoryColors.textSecondary,
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
      throw StateError('Evidence share card not ready to render');
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
    required EvidenceProofArtifact artifact,
  }) async {
    final file = await renderPngFile(
      boundaryKey: boundaryKey,
      filename: artifact.pngFilename,
    );
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
  }
}

class _BandPalette {
  const _BandPalette({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;
}

_BandPalette _paletteFor(PatternMatchConfidenceBand band) {
  return switch (band) {
    PatternMatchConfidenceBand.weak => const _BandPalette(
      label: 'Weak',
      background: VoiceMemoryColors.surfaceSecondary,
      border: VoiceMemoryColors.border,
      foreground: VoiceMemoryColors.textSecondary,
    ),
    PatternMatchConfidenceBand.emerging => _BandPalette(
      label: 'Emerging',
      background: VoiceMemoryColors.discoveryGoldBackground,
      border: VoiceMemoryColors.blindSpotAmber.withValues(alpha: 0.45),
      foreground: VoiceMemoryColors.blindSpotAmber,
    ),
    PatternMatchConfidenceBand.solid => _BandPalette(
      label: 'Solid',
      background: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.1),
      border: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.35),
      foreground: VoiceMemoryColors.beliefIndigo,
    ),
    PatternMatchConfidenceBand.strong => _BandPalette(
      label: 'Strong',
      background: VoiceMemoryColors.success.withValues(alpha: 0.12),
      border: VoiceMemoryColors.success.withValues(alpha: 0.4),
      foreground: VoiceMemoryColors.success,
    ),
  };
}