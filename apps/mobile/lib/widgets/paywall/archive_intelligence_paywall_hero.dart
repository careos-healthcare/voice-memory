import 'dart:math' as math;

import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/archive_paywall_stats.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Hero band for the intelligence paywall — gradient, abstract archive motif,
/// and optional real stats from [ArchivePaywallStats].
class ArchiveIntelligencePaywallHero extends StatelessWidget {
  const ArchiveIntelligencePaywallHero({
    required this.headline,
    required this.subheadline,
    super.key,
    this.stats,
    this.positioningLine,
  });

  final String headline;
  final String subheadline;
  final ArchivePaywallStats? stats;
  final String? positioningLine;

  @override
  Widget build(BuildContext context) {
    final wide = ArchiveResponsiveLayout.isTabletOrDesktop(context);
    final hasRibbon = stats != null && stats!.hasRichStats;
    final minHeight = wide
        ? (hasRibbon ? 300.0 : 260.0)
        : (hasRibbon ? 248.0 : 220.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(wide ? 24 : 20),
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Stack(
          fit: StackFit.passthrough,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF4F0FF),
                      Color(0xFFE8EEFC),
                      Color(0xFFFFF8F0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _ArchiveHeroPatternPainter()),
            ),
            Padding(
              padding: ArchiveResponsiveLayout.cardInsets(context).copyWith(
                top: wide ? 28 : 22,
                bottom: wide ? 24 : 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasRibbon) ...[
                    _HeroStatsRibbon(stats: stats!),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    headline,
                    key: const Key('paywall_hero_headline'),
                    style: ArchiveMobileTypography.responsivePageTitle(context)
                        .copyWith(fontSize: wide ? 28 : 24, height: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  if (positioningLine != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      positioningLine!,
                      key: const Key('paywall_positioning_line'),
                      style: ArchiveMobileTypography.responsiveSectionTitle(
                        context,
                      ).copyWith(fontSize: wide ? 17 : 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    subheadline,
                    style: ArchiveMobileTypography.responsiveBody(context)
                        .copyWith(color: VoiceMemoryColors.textSecondary),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _HeroStatsRibbon extends StatelessWidget {
  const _HeroStatsRibbon({required this.stats});

  final ArchivePaywallStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('paywall_hero_stats_ribbon'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: ArchivePaywallCopy.heroGeneratedFromLabel,
              value: stats.heroRecordingLine(),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: VoiceMemoryColors.border,
          ),
          Expanded(
            child: _StatChip(
              label: ArchivePaywallCopy.heroAcrossLabel,
              value: stats.heroSpanLine(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: ArchiveMobileTypography.responsiveHelper(context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: ArchiveMobileTypography.listTitle(context).copyWith(
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ArchiveHeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final nodes = <Offset>[
      Offset(size.width * 0.18, size.height * 0.72),
      Offset(size.width * 0.38, size.height * 0.48),
      Offset(size.width * 0.58, size.height * 0.62),
      Offset(size.width * 0.78, size.height * 0.38),
      Offset(size.width * 0.88, size.height * 0.58),
    ];

    final linePaint = Paint()
      ..color = VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], linePaint);
    }

    for (var i = 0; i < nodes.length; i++) {
      final pulse = 0.55 + 0.45 * math.sin(i * 1.4);
      final radius = 4 + pulse * 3;
      canvas.drawCircle(
        nodes[i],
        radius,
        Paint()
          ..color = VoiceMemoryColors.primaryIndigo.withValues(
            alpha: 0.12 + pulse * 0.12,
          ),
      );
      canvas.drawCircle(
        nodes[i],
        2.5,
        Paint()..color = VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}