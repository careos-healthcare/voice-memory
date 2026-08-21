import 'package:archiveme_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/product/loop_mode_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact Loop Mode progress on Record and Patterns tabs.
class LoopModeProgressCard extends StatelessWidget {
  const LoopModeProgressCard({
    required this.loop, required this.onRecordNext, super.key,
    this.compact = false,
    this.showRecordCta = true,
  });

  final LoopMode loop;
  final VoidCallback onRecordNext;
  final bool compact;
  final bool showRecordCta;

  static const _engine = LoopModeEngine();

  @override
  Widget build(BuildContext context) {
    final status = _engine.progressStatus(loop);
    final statusLabel = _engine.progressStatusLabel(status);
    final fraction = _engine.progressFraction(loop);
    final nextPrompt = _engine.nextPrompt(loop);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FBFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loop.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$fraction · $statusLabel',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              nextPrompt,
              style: VoiceMemoryTypography.bodyStyle().copyWith(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
          if (showRecordCta) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRecordNext,
              child: Text(LoopModeCopy.progressRecordCtaForLoop(loop.id)),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          OutlinedButton(
            onPressed: () => context.push('/loop-mode'),
            child: const Text(LoopModeCopy.progressViewLoopCta),
          ),
        ],
      ),
    );
  }
}