import 'package:archiveme_mobile/features/insight_share/insight_share_card_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Fixed-size weekly insight snapshot card for PNG export.
class InsightShareCardWidget extends StatelessWidget {
  const InsightShareCardWidget({
    required this.model,
    super.key,
    this.exportKey,
    this.fixedWidth = exportWidth,
  });

  final InsightShareCardModel model;
  final GlobalKey? exportKey;
  final double fixedWidth;

  static const double exportWidth = 360;
  static const double exportMinHeight = 420;

  @override
  Widget build(BuildContext context) {
    final key = exportKey ?? GlobalKey();

    return RepaintBoundary(
      key: key,
      child: SizedBox(
        width: fixedWidth,
        child: Container(
          key: const Key('insight_share_card_widget'),
          width: fixedWidth,
          constraints: const BoxConstraints(minHeight: exportMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF09090B), Color(0xFF18181B)],
            ),
            border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.35)),
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
                model.footer,
                key: const Key('insight_share_card_brand'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                model.headline,
                key: const Key('insight_share_card_headline'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                model.weekRangeLabel,
                key: const Key('insight_share_card_week_range'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              for (final line in model.patternLines) ...[
                Text(
                  '• $line',
                  key: Key('insight_share_card_line_${line.hashCode}'),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              const Text(
                'Patterns only — no private journal text',
                key: const Key('insight_share_card_privacy_note'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}