import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/confirmed_repeat_thought_map_copy.dart';
import '../../features/early_archive/confirmed_repeat_thought_map_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Loop map card after confirmed-repeat proof — prompts only when unknown.
class ConfirmedRepeatThoughtMapCard extends StatelessWidget {
  const ConfirmedRepeatThoughtMapCard({
    super.key,
    required this.result,
    required this.showRecordMissingPieceCta,
    this.onRecordMissingPiece,
  });

  final ThoughtMapResult result;
  final bool showRecordMissingPieceCta;
  final VoidCallback? onRecordMissingPiece;

  @override
  Widget build(BuildContext context) {
    final questionStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontSize: 12,
      height: 1.35,
    );
    final knownStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final unknownStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      fontStyle: FontStyle.italic,
      height: 1.45,
    );

    return Container(
      key: const Key('confirmed_repeat_thought_map_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.title,
            key: const Key('confirmed_repeat_thought_map_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final section in result.sections) ...[
            _SectionRow(
              section: section,
              questionStyle: questionStyle,
              knownStyle: knownStyle,
              unknownStyle: unknownStyle,
            ),
            if (section != result.sections.last)
              const SizedBox(height: AppSpacing.sm),
          ],
          if (showRecordMissingPieceCta &&
              result.firstMissingSection != null &&
              onRecordMissingPiece != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('confirmed_repeat_thought_map_record_cta'),
                onPressed: onRecordMissingPiece,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(ConfirmedRepeatThoughtMapCopy.recordMissingPieceCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.questionStyle,
    required this.knownStyle,
    required this.unknownStyle,
  });

  final ThoughtMapSection section;
  final TextStyle questionStyle;
  final TextStyle knownStyle;
  final TextStyle unknownStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section.label,
          key: Key('confirmed_repeat_thought_map_label_${section.id.name}'),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 2),
        Text(
          section.question,
          key: Key('confirmed_repeat_thought_map_question_${section.id.name}'),
          style: questionStyle,
        ),
        const SizedBox(height: 4),
        Text(
          section.displayText,
          key: Key('confirmed_repeat_thought_map_body_${section.id.name}'),
          style: section.isKnown ? knownStyle : unknownStyle,
        ),
      ],
    );
  }
}
