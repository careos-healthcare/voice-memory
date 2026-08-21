import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/record/record_how_it_works_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Loop + timeline education — opened from Record first-run “How it works”.
Future<void> showRecordHowItWorksSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final bodyStyle = ArchiveMobileTypography.body(
        sheetContext,
      ).copyWith(height: 1.45);
      final stepTitleStyle = ArchiveMobileTypography.cardLabel(sheetContext);
      final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                RecordHowItWorksCopy.sheetTitle,
                key: const Key('record_how_it_works_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(
                  sheetContext,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < RecordHowItWorksCopy.steps.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                Text(
                  RecordHowItWorksCopy.steps[i].title,
                  key: Key('record_how_it_works_step_title_$i'),
                  style: stepTitleStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  RecordHowItWorksCopy.steps[i].body,
                  key: Key('record_how_it_works_step_body_$i'),
                  style: secondaryStyle,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                RecordHowItWorksCopy.chatGptLine,
                key: const Key('record_how_it_works_chatgpt_line'),
                style: secondaryStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                RecordHowItWorksCopy.timelineHeading,
                key: const Key('record_how_it_works_timeline_heading'),
                style: stepTitleStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final bullet in RecordHowItWorksCopy.timelineBullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: bodyStyle),
                      Expanded(
                        child: Text(
                          bullet,
                          key: Key('record_how_it_works_timeline_$bullet'),
                          style: bodyStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const Key('record_how_it_works_done'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text(RecordHowItWorksCopy.doneLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}