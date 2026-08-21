import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/early_archive/positive_pattern_copy.dart';
import 'package:archiveme_mobile/features/early_archive/positive_pattern_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Surfaces repeated helpful actions from the user's own entries.
class PositivePatternCard extends StatelessWidget {
  const PositivePatternCard({
    required this.result, required this.showRecordAgainCta, super.key,
    this.onRecordAgain,
  });

  final PositivePatternResult result;
  final bool showRecordAgainCta;
  final VoidCallback? onRecordAgain;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final evidenceStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('positive_pattern_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.title,
            key: const Key('positive_pattern_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: const Key('positive_pattern_body'),
            style: bodyStyle,
          ),
          if (result.evidencePhrases.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final phrase in result.evidencePhrases.skip(1))
              Padding(
                key: Key('positive_pattern_evidence_$phrase'),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(phrase, style: evidenceStyle),
              ),
          ],
          if (showRecordAgainCta && onRecordAgain != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('positive_pattern_record_cta'),
                onPressed: onRecordAgain,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(PositivePatternCopy.recordAgainCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}