import 'package:archiveme_mobile/features/insights/theme_frequency.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

final _metricNoise = RegExp(
  r'\([^)]*(%|\bscore\b|\bconfidence\b|\d+\s*/\s*\d+)[^)]*\)'
  r'|\d+\s*%(\s*match)?'
  r'|\bscore\s*:\s*\d+\s*/\s*\d+'
  r'|\bconfidence\s*:\s*\d+\s*%?',
  caseSensitive: false,
);

/// Drops percentages, scores, and confidence figures from a theme label.
String plainThemeLabel(String raw) {
  return raw
      .replaceAll(_metricNoise, '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

class _CitedTheme {
  const _CitedTheme({required this.label, required this.entries});

  final String label;
  final List<JournalEntry> entries;

  List<String> get entryIds => [for (final entry in entries) entry.id];
}

List<_CitedTheme> citedThemes(List<JournalEntry> entries) {
  final grouped = <String, List<JournalEntry>>{};
  final labels = <String, String>{};
  for (final entry in entries) {
    for (final raw in entry.reflection.recurringThemes) {
      final label = plainThemeLabel(raw);
      if (label.isEmpty) continue;
      final key = label.toLowerCase();
      labels[key] = label;
      final bucket = grouped.putIfAbsent(key, () => []);
      if (bucket.every((saved) => saved.id != entry.id)) bucket.add(entry);
    }
  }
  if (grouped.isNotEmpty) {
    return [
      for (final entry in grouped.entries)
        _CitedTheme(label: labels[entry.key]!, entries: entry.value),
    ];
  }

  final pairs = ThemeFrequency.analyze([
    for (final entry in entries) (id: entry.id, text: entry.transcript),
  ]);
  if (pairs.isEmpty) return const [];
  final theme = pairs.first;
  final byId = {for (final entry in entries) entry.id: entry};
  return [
    _CitedTheme(
      label: theme.sentence,
      entries: [
        for (final id in theme.entryIds)
          if (byId[id] != null) byId[id]!,
      ],
    ),
  ];
}

/// Shows recurring themes and the saved words that produced each one.
class RecurringThemesView extends StatelessWidget {
  const RecurringThemesView({required this.entries, super.key});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final themes = citedThemes(entries);
    if (themes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final theme in themes)
            _ThemeCard(theme: theme),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme});

  final _CitedTheme theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('recurring_theme_${theme.label}'),
        onTap: () => _openCitations(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(theme.label, key: Key('recurring_theme_sentence_${theme.label}')),
              ViewEvidenceInlineLink(
                entryIds: theme.entryIds,
                surface: 'pattern_exploration',
                claimContext: theme.label,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCitations(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.6;
        return SafeArea(
          child: SizedBox(
            key: const Key('theme_citation_sheet'),
            height: height,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  theme.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final entry in theme.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      entry.transcript.trim().isEmpty
                          ? 'Transcript processing…'
                          : entry.transcript.trim(),
                      key: Key('theme_verbatim_${entry.id}'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
