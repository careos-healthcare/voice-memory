import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_hints.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Dismissible local hint for the Archive/Patterns workspace.
class ArchiveWorkspaceHintCard extends StatelessWidget {
  const ArchiveWorkspaceHintCard({
    required this.hint, required this.onDismiss, super.key,
  });

  final ArchiveWorkspaceHint hint;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final compactBodyStyle = bodyStyle.copyWith(
      color: AppColors.textSecondary,
      fontSize: (bodyStyle.fontSize ?? 14) - 1,
    );

    return Container(
      key: Key('archive_workspace_hint_${hint.hintId}'),
      width: double.infinity,
      padding: EdgeInsets.all(hint.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F7FB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hint.title case final title?) ...[
                      Text(
                        title,
                        key: Key('archive_workspace_hint_title_${hint.hintId}'),
                        style: titleStyle,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ] else if (hint.compact) ...[
                      Text(
                        VisibleArchiveProofCopy
                            .archiveWorkspaceHintSectionPrompt,
                        key: Key(
                          'archive_workspace_hint_section_prompt_${hint.hintId}',
                        ),
                        style: compactBodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      hint.body,
                      key: Key('archive_workspace_hint_body_${hint.hintId}'),
                      style: hint.compact ? compactBodyStyle : bodyStyle,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('archive_workspace_hint_dismiss_${hint.hintId}'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  size: hint.compact ? 18 : 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}