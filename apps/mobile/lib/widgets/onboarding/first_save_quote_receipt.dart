import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/onboarding/first_session_evidence.dart';
import 'package:archiveme_mobile/features/onboarding/first_session_evidence_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_debug_actions.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Quotes the first recording back. No interpretation and no advice.
class FirstSaveQuoteReceipt extends StatelessWidget {
  const FirstSaveQuoteReceipt({
    required this.quotes,
    super.key,
    this.audioPath,
    this.onPlay,
    this.onRemindYes,
    this.onRemindNotNow,
  });

  final List<VerbatimQuoteSpan> quotes;
  final String? audioPath;
  final VoidCallback? onPlay;
  final VoidCallback? onRemindYes;
  final VoidCallback? onRemindNotNow;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) return const SizedBox.shrink();
    final path = audioPath;
    return Card(
      key: const Key('first_save_quote_receipt'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FirstSessionEvidenceCopy.quoteTitle,
              key: const Key('first_save_quote_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (var i = 0; i < quotes.length; i++) ...[
              const SizedBox(height: AppSpacing.sm),
              UserWordsQuote(
                key: Key('first_save_quote_span_$i'),
                text: quotes[i].text,
              ),
              Text(
                formatEvidenceTimestamp(quotes[i].recordedAt),
                key: Key('first_save_quote_time_$i'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (path != null && path.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ActionChip(
                key: const Key('first_save_quote_play_chip'),
                avatar: const Icon(Icons.play_arrow, size: 18),
                label: const Text(FirstSessionEvidenceCopy.playChip),
                onPressed: onPlay ?? () => AudioDebugActions.playRecording(path),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              FirstSessionEvidenceCopy.remindQuestion,
              key: const Key('first_save_quote_remind_question'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton(
                  key: const Key('first_save_quote_remind_yes'),
                  onPressed: onRemindYes,
                  child: const Text(FirstSessionEvidenceCopy.remindYes),
                ),
                TextButton(
                  key: const Key('first_save_quote_remind_not_now'),
                  onPressed: onRemindNotNow,
                  child: const Text(FirstSessionEvidenceCopy.remindNotNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
