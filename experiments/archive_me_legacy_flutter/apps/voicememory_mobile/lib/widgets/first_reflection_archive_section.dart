import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/empty_archive_experience.dart';
import '../features/first_reflection/first_reflection_insights.dart';
import '../features/impossible_insight/impossible_insight_engine.dart';
import '../features/explainable_conclusion/explainable_conclusion_widgets.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';
import 'archive_quick_explain_card.dart';
import 'top_themes_section.dart';

/// Early archive (< 5 reflections) — noticed themes and phrases, not empty belief UI.
class FirstReflectionArchiveSection extends StatelessWidget {
  const FirstReflectionArchiveSection({super.key, required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final impossible = entries.length <= 5
        ? const ImpossibleInsightEngine().build(entries)
        : null;
    if (impossible != null) {
      return Column(
        key: const Key('first_reflection_impossible_insight'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExplainableConclusionCard(conclusion: impossible.conclusion),
          const SizedBox(height: 12),
          Text(
            impossible.nextEvidenceQuestion,
            key: const Key('first_reflection_impossible_next_question'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/record'),
            child: const Text('Record another moment'),
          ),
        ],
      );
    }
    final insights = buildFirstReflectionInsights(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveQuickExplainCard(reflectionCount: insights.reflectionCount),
        const SizedBox(height: 20),
        const Text(
          'WHAT YOUR ARCHIVE NOTICED',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 10),
        if (insights.noticedLines.isNotEmpty)
          ...insights.noticedLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppTheme.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          const Text(
            'Your archive is listening. Add a little more spoken detail in your '
            'next moment so themes and phrases can surface.',
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          ),
        const SizedBox(height: 20),
        const Text(
          'DETECTED THEMES',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 10),
        TopThemesSection(entries: entries),
        const SizedBox(height: 20),
        const Text(
          'INTERESTING PHRASES',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 10),
        if (insights.phrases.isEmpty)
          const Text(
            'Exact phrases from your recordings will show here as you add moments.',
            style: TextStyle(color: AppTheme.muted, height: 1.45, fontSize: 13),
          )
        else
          ...insights.phrases.map(
            (phrase) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '“$phrase”',
                style: const TextStyle(
                  color: AppTheme.muted,
                  height: 1.45,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.muted.withValues(alpha: 0.25)),
          ),
          child: Text(
            '$firstReflectionDisclaimer '
            '(${insights.reflectionCount} of $firstReflectionModeThreshold saved moments so far.)',
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.go('/record'),
          child: const Text('Record another moment'),
        ),
      ],
    );
  }
}

/// Pre-first recording — still not an empty archive shell.
class FirstReflectionEmptyArchiveSection extends StatelessWidget {
  const FirstReflectionEmptyArchiveSection({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyArchivePanel.firstRecording(
      onRecord: () => goToFirstRecording(context),
    );
  }
}
