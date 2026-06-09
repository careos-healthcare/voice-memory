import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/pattern_memory/pattern_share_recap_model.dart';
import '../../features/pattern_memory/pattern_share_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Lets the user keep this week's pattern by copying or sharing a text recap.
class PatternShareRecapCard extends StatefulWidget {
  const PatternShareRecapCard({super.key, required this.recap});

  final PatternShareRecap recap;

  static const String title = 'Keep this pattern';
  static const String subtitle =
      'Save this week\u2019s recap or share it with someone you trust.';
  static const String copyCta = 'Copy recap';
  static const String shareCta = 'Share';

  static const Color _surface = Color(0xFFEFF4FB);
  static const Color _border = Color(0xFFD6E2F2);

  @override
  State<PatternShareRecapCard> createState() => _PatternShareRecapCardState();
}

class _PatternShareRecapCardState extends State<PatternShareRecapCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackPatternShareCardShown();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copy() async {
    await PatternShareService.copyToClipboard(widget.recap);
    _snack('Recap copied.');
  }

  Future<void> _share() async {
    final shared = await PatternShareService.shareText(widget.recap);
    // When native share is unavailable the service copies instead, so surface
    // the copy confirmation rather than leaving the tap silent.
    if (!shared) {
      _snack('Recap copied.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recap = widget.recap;
    final previewLines = recap.lines.take(2).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: PatternShareRecapCard._surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PatternShareRecapCard._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PatternShareRecapCard.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PatternShareRecapCard.subtitle,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PatternShareRecapCard._border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recap.title,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  recap.body,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 13, height: 1.4),
                ),
                for (final line in previewLines) ...[
                  const SizedBox(height: 4),
                  Text(
                    '\u2022 $line',
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _copy,
                  child: const Text(PatternShareRecapCard.copyCta),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _share,
                  child: const Text(PatternShareRecapCard.shareCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
