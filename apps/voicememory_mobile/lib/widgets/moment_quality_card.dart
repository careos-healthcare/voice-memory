import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/moment_quality/moment_quality_copy.dart';
import '../features/moment_quality/moment_quality_engine.dart';
import '../features/moment_quality/moment_quality_gates.dart';
import '../features/moment_quality/moment_quality_models.dart';
import '../features/moment_quality/post_save_moment_detail_model.dart';
import '../models/journal_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Compact local helper for drafting stronger archive evidence.
class MomentQualityCard extends StatelessWidget {
  const MomentQualityCard({
    super.key,
    required this.text,
    this.engine = const MomentQualityEngine(),
    this.onSuggestionTap,
  });

  final String text;
  final MomentQualityEngine engine;
  final void Function(PostSaveMomentDetailType detailType)? onSuggestionTap;

  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    if (!MomentQualityGates.showForDraft(text)) {
      return const SizedBox.shrink(key: Key('moment_quality_card_hidden'));
    }

    final result = engine.evaluate(text);
    if (!result.isVisible) {
      return const SizedBox.shrink(key: Key('moment_quality_card_hidden'));
    }

    return Container(
      key: Key('moment_quality_card_${result.level.name}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MomentQualityCopy.helperLabel,
            key: const Key('moment_quality_helper_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.title,
            key: Key('moment_quality_title_${result.level.name}'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: Key('moment_quality_body_${result.level.name}'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (result.suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final suggestion in result.suggestions)
                  _SuggestionChip(
                    key: Key('moment_quality_suggestion_${suggestion.hashCode}'),
                    label: suggestion,
                    onTap: _onTapFor(suggestion),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  VoidCallback? _onTapFor(String suggestion) {
    final detailType = PostSaveMomentDetailType.forSuggestion(suggestion);
    if (detailType == null || onSuggestionTap == null) return null;
    return () => onSuggestionTap!(detailType);
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: ArchiveMobileTypography.listSubtitle(context),
    );

    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MomentQualityCard._border),
        ),
        child: child,
      );
    }

    return Material(
      color: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: MomentQualityCard._border),
      ),
      child: InkWell(
        key: Key('moment_quality_suggestion_tap_${label.hashCode}'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Saved-moment variant for post-save surfaces.
class SavedMomentQualityCard extends StatelessWidget {
  const SavedMomentQualityCard({
    super.key,
    required this.transcript,
    required this.entry,
    this.engine = const MomentQualityEngine(),
    this.onSuggestionTap,
  });

  final String transcript;
  final JournalEntry entry;
  final MomentQualityEngine engine;
  final void Function(PostSaveMomentDetailType detailType)? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    if (!MomentQualityGates.showForSavedMoment(transcript)) {
      return const SizedBox.shrink(key: Key('moment_quality_saved_hidden'));
    }
    return MomentQualityCard(
      text: transcript,
      engine: engine,
      onSuggestionTap: onSuggestionTap,
    );
  }
}
