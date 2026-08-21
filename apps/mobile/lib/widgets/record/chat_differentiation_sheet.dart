import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/chat_differentiation/chat_differentiation_copy.dart';
import 'package:archiveme_mobile/features/chat_differentiation/chat_differentiation_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Small bottom sheet explaining ArchiveMe vs chat — timeline from saved dates only.
class ChatDifferentiationSheet extends StatelessWidget {
  const ChatDifferentiationSheet({required this.timelineRows, super.key});

  final List<ChatDifferentiationTimelineRow> timelineRows;

  static Future<void> show(
    BuildContext context, {
    required List<ChatDifferentiationTimelineRow> timelineRows,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ChatDifferentiationSheet(timelineRows: timelineRows),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('chat_differentiation_sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ChatDifferentiationCopy.sheetTitle,
                key: const Key('chat_differentiation_sheet_title'),
                style: titleStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ChatDifferentiationCopy.sheetBody,
                key: const Key('chat_differentiation_sheet_body'),
                style: secondaryStyle,
              ),
              if (timelineRows.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                for (final row in timelineRows) ...[
                  Text(
                    row.label,
                    key: Key(
                      'chat_differentiation_timeline_label_${row.label}',
                    ),
                    style: labelStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.dateLabel,
                    key: Key(
                      'chat_differentiation_timeline_date_${row.label.hashCode}',
                    ),
                    style: bodyStyle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
              Text(
                ChatDifferentiationCopy.sheetCloseLine,
                key: const Key('chat_differentiation_sheet_close'),
                style: bodyStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}