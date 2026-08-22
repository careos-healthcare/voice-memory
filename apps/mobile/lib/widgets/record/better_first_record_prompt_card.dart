import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Gated first-record helper shown when people struggle to save the first moment.
class BetterFirstRecordPromptCard extends StatefulWidget {
  const BetterFirstRecordPromptCard({required this.onRecord, super.key});

  final VoidCallback onRecord;

  static const String title = 'Start with one ordinary moment';
  static const String body =
      'Do not explain your whole day. Say one moment that stayed with you.';
  static const List<String> examples = [
    'I said yes too fast.',
    'I kept thinking about the same thing.',
    'I felt drained after a conversation.',
  ];
  static const String cta = 'Record that moment';

  @override
  State<BetterFirstRecordPromptCard> createState() =>
      _BetterFirstRecordPromptCardState();
}

class _BetterFirstRecordPromptCardState
    extends State<BetterFirstRecordPromptCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackBetterFirstRecordPromptShown();
  }

  void _onRecord() {
    ActivationTracker.trackBetterFirstRecordPromptTapped();
    widget.onRecord();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BetterFirstRecordPromptCard.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            BetterFirstRecordPromptCard.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in BetterFirstRecordPromptCard.examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 14, height: 1.45),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 14, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _onRecord,
              child: const Text(BetterFirstRecordPromptCard.cta),
            ),
          ),
        ],
      ),
    );
  }
}