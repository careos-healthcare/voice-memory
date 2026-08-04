import 'package:flutter/material.dart';

import '../features/immediate_archive_value/immediate_archive_value_engine.dart';
import '../features/impossible_insight/impossible_insight_engine.dart';
import '../features/explainable_conclusion/explainable_conclusion_widgets.dart';
import '../models/journal_entry.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_theme.dart';
import 'archive_insight_card_shell.dart';
import 'expandable_observation_field.dart';

/// Recording #1 — primary theme, quote, phrase, observation.
class FirstArchiveInsightSection extends StatelessWidget {
  const FirstArchiveInsightSection({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final insight = buildFirstRecordingInsight(entries);
    final sorted = [...entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final evidenceEntryId = sorted.isNotEmpty ? sorted.first.id : null;
    final related = sorted.take(4).toList();
    if (entries.length <= 1) {
      final hasGroundedObservation =
          insight.firstObservation != null && insight.strongestQuote != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            ConsumerUiCopy.archiveMeNoticedHeading,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ArchiveInsightCardShell(
            sectionTitle: ConsumerUiCopy.archiveMeNoticedTitle,
            children: [
              if (hasGroundedObservation) ...[
                ExpandableObservationField(
                  label: 'Observation',
                  value: insight.firstObservation!,
                  entryId: evidenceEntryId,
                  relatedEntries: related,
                  rationale: 'Drawn from the exact words in your saved moment.',
                ),
                ArchiveInsightField(
                  label: 'Supporting words',
                  value: '“${insight.strongestQuote!}”',
                ),
              ] else
                const ArchiveInsightField(
                  label: 'Early read',
                  value:
                      'There is not enough detail for a reliable observation yet.',
                ),
            ],
          ),
        ],
      );
    }

    final impossible = entries.length <= 5
        ? const ImpossibleInsightEngine().build(entries)
        : null;
    if (impossible != null) {
      return Column(
        key: const Key('first_archive_impossible_insight'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExplainableConclusionCard(conclusion: impossible.conclusion),
          const SizedBox(height: 10),
          Text(
            impossible.nextEvidenceQuestion,
            key: const Key('first_archive_impossible_next_question'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          ConsumerUiCopy.archiveMeNoticedHeading,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ArchiveInsightCardShell(
          sectionTitle: ConsumerUiCopy.archiveMeNoticedTitle,
          children: [
            if (insight.primaryTheme != null)
              ArchiveInsightField(label: 'Theme', value: insight.primaryTheme!)
            else
              const ArchiveInsightField(
                label: 'Theme',
                value: 'Patterns will appear as you add more spoken detail.',
              ),
            if (insight.strongestQuote != null)
              ArchiveInsightField(
                label: 'Quote',
                value: '“${insight.strongestQuote!}”',
              )
            else
              const ArchiveInsightField(
                label: 'Quote',
                value:
                    'A standout line will appear when your transcript has enough detail.',
              ),
            if (insight.interestingPhrase != null)
              ArchiveInsightField(
                label: 'Interesting phrase',
                value: '“${insight.interestingPhrase!}”',
              )
            else
              const ArchiveInsightField(
                label: 'Interesting phrase',
                value:
                    'Distinctive wording from your recording will show here.',
              ),
            if (insight.firstObservation != null)
              ExpandableObservationField(
                label: 'Observation',
                value: insight.firstObservation!,
                entryId: evidenceEntryId,
                relatedEntries: related,
                rationale: 'Drawn from the exact words in your saved moment.',
              )
            else
              const ArchiveInsightField(
                label: 'Observation',
                value:
                    'Add a little more detail in your recording and ArchiveMe can summarize what you focused on.',
              ),
          ],
        ),
      ],
    );
  }
}
