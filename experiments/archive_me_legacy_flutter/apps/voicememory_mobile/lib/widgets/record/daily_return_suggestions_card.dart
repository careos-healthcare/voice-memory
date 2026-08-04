import 'package:flutter/material.dart';

import '../../features/pressure_retention/daily_return_suggestion_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_typography.dart';

/// Compact "Worth checking today" list above the Record prompt area.
///
/// Each row is a tappable suggestion built from the user's own entries.
/// Tapping selects the row's prompt via [onSelectPrompt] — the same path as
/// the existing starter prompt cards. Renders nothing without suggestions.
class DailyReturnSuggestionsCard extends StatelessWidget {
  const DailyReturnSuggestionsCard({
    super.key,
    required this.suggestionSet,
    required this.onSelectPrompt,
    this.selectedPrompt,
    this.onSuggestionTap,
    this.startHereOnly = false,
  });

  final DailyReturnSuggestionSet suggestionSet;
  final ValueChanged<String> onSelectPrompt;
  final String? selectedPrompt;

  /// When true, renders only the single "Start here today" pick — no
  /// "Worth checking today" list heading or secondary rows.
  final bool startHereOnly;

  /// Optional tap detail for local attribution — which suggestion was tapped
  /// and whether it was the primary "Start here today" pick.
  final void Function(DailyReturnSuggestion suggestion, bool isPrimary)?
  onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    if (!suggestionSet.hasSuggestions) return const SizedBox.shrink();
    final recommended = suggestionSet.recommendedSuggestion!;
    final others = suggestionSet.otherSuggestions;

    if (startHereOnly) {
      return Container(
        key: const Key('start_here_today_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: VoiceMemoryCards.flat(
          background: AppColors.backgroundSecondary,
        ),
        child: _PrimaryRecommendation(
          suggestion: recommended,
          reason: suggestionSet.recommendationReason,
          selected: selectedPrompt == recommended.prompt,
          onTap: () {
            onSuggestionTap?.call(recommended, true);
            onSelectPrompt(recommended.prompt);
          },
        ),
      );
    }

    return Container(
      key: const Key('daily_return_suggestions_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DailyReturnSuggestionSet.heading,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            DailyReturnSuggestionSet.subLabel,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _PrimaryRecommendation(
            suggestion: recommended,
            reason: suggestionSet.recommendationReason,
            selected: selectedPrompt == recommended.prompt,
            onTap: () {
              onSuggestionTap?.call(recommended, true);
              onSelectPrompt(recommended.prompt);
            },
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              DailyReturnSuggestionSet.othersHeading,
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ),
            ),
            for (final suggestion in others)
              _SuggestionRow(
                suggestion: suggestion,
                selected: selectedPrompt == suggestion.prompt,
                onTap: () {
                  onSuggestionTap?.call(suggestion, false);
                  onSelectPrompt(suggestion.prompt);
                },
              ),
          ],
        ],
      ),
    );
  }
}

/// The single "Start here today" pick — visually primary but still compact.
class _PrimaryRecommendation extends StatelessWidget {
  const _PrimaryRecommendation({
    required this.suggestion,
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final DailyReturnSuggestion suggestion;
  final String reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${DailyReturnSuggestionSet.primaryHeading}. '
          '${suggestion.title}. ${suggestion.prompt}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: const Key('daily_return_primary_recommendation'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentPrimary,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? AppColors.accentLight : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DailyReturnSuggestionSet.primaryHeading,
                style: VoiceMemoryTypography.metadataStyle(
                  color: AppColors.accentPrimary,
                ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                suggestion.title,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                suggestion.prompt,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (suggestion.evidenceSnippet != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${DailyReturnSuggestionSet.evidenceLabel} '
                  '\u201C${suggestion.evidenceSnippet}\u201D',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '${DailyReturnSuggestionSet.whyLabel}: $reason',
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.selected,
    required this.onTap,
  });

  final DailyReturnSuggestion suggestion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${suggestion.title}. ${suggestion.prompt}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.accentPrimary
                  : AppColors.borderSubtle,
            ),
            color: selected ? AppColors.accentLight : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.title,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                suggestion.prompt,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (suggestion.reason.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  suggestion.reason,
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 11),
                ),
              ],
              if (suggestion.evidenceSnippet != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${DailyReturnSuggestionSet.evidenceLabel} '
                  '\u201C${suggestion.evidenceSnippet}\u201D',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VoiceMemoryTypography.metadataStyle(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
