import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Local agree / disagree / correct handlers for archive insight cards.
abstract final class InsightEvidenceFeedbackActions {
  InsightEvidenceFeedbackActions._();

  static Future<void> agree(String insightId) async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    await ArchiveInsightFeedbackStore.record(
      insightId,
      ArchiveInsightFeedbackChoice.feelsRight,
    );
  }

  static Future<void> disagree(String insightId) async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    await ArchiveInsightFeedbackStore.record(
      insightId,
      ArchiveInsightFeedbackChoice.notQuite,
    );
  }

  static Future<bool> correct(
    BuildContext context, {
    required String insightId,
  }) async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    await ArchiveInsightFeedbackStore.record(
      insightId,
      ArchiveInsightFeedbackChoice.notQuite,
    );

    final controller = TextEditingController(
      text: ArchiveInsightFeedbackStore.correctionNote(insightId) ?? '',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ArchiveInsightFeedbackCopy.correctionAffordance,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: ArchiveInsightFeedbackStore.maxCorrectionNoteLength,
                decoration: const InputDecoration(
                  hintText: ArchiveInsightFeedbackCopy.correctionPlaceholder,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () async {
                  final saved = await ArchiveInsightFeedbackStore
                      .saveCorrectionNote(insightId, controller.text);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop(saved);
                },
                child: const Text(ArchiveInsightFeedbackCopy.correctionSaveCta),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    return saved == true;
  }
}