import 'package:archiveme_mobile/design/empty_archive_experience.dart';
import 'package:archiveme_mobile/features/first_reflection/first_reflection_insights.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive_quick_explain_card.dart';
import 'package:archiveme_mobile/widgets/top_themes_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Early archive (< 5 reflections) — noticed themes and phrases, not empty belief UI.
class FirstReflectionArchiveSection extends StatelessWidget {
  const FirstReflectionArchiveSection({required this.entries, super.key});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
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
            'next reflection so themes and phrases can surface.',
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
            'Exact phrases from your recordings will show here as you add reflections.',
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
            '(${insights.reflectionCount} of $firstReflectionModeThreshold reflections so far.)',
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
          child: const Text('Add another reflection'),
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